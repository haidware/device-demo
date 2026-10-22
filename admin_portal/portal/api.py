import json
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlsplit
from urllib.request import Request, urlopen

from django.conf import settings
from django.db import transaction
from django.db.models import Q
from django.http import HttpResponse, JsonResponse
from django.urls import reverse
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods

from .models import (
    Device,
    MenuItem,
    Order,
    OrderLine,
    PortalSettings,
    ServiceOption,
    ServiceRequest,
)
from .routing import _record_routing_attempts

MAX_MENU_IMAGE_BYTES = 5 * 1024 * 1024
MENU_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}


def _json_body(request):
    try:
        data = json.loads(request.body or b"{}")
    except (json.JSONDecodeError, UnicodeDecodeError):
        return None, JsonResponse({"error": "Request body must be valid JSON."}, status=400)
    if not isinstance(data, dict):
        return None, JsonResponse({"error": "JSON body must be an object."}, status=400)
    return data, None


def _device_from_id(device_id):
    if not isinstance(device_id, str) or not device_id.isdigit():
        return None
    return (
        Device.objects.select_related("room")
        .filter(device_id=device_id, active=True)
        .filter(Q(room__isnull=True) | Q(room__active=True))
        .first()
    )


def _device_error():
    return JsonResponse({"error": "Device ID is invalid or inactive."}, status=403)


def _menu_item_payload(request, item):
    return {
        "id": item.pk,
        "name": item.name,
        "description": item.description,
        "category": item.category,
        "department": item.department,
        "price": str(item.price),
        "preparation_minutes": item.preparation_minutes,
        "estimated_minutes": item.preparation_minutes,
        "available": item.available,
        "image_url": (
            request.build_absolute_uri(reverse("api_menu_image", args=[item.pk]))
            if item.image_url
            else None
        ),
    }


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def device_session(request):
    if request.method == "OPTIONS":
        return JsonResponse({}, status=204)
    data, error = _json_body(request)
    if error:
        return error
    device = _device_from_id(data.get("device_id"))
    if not device:
        return _device_error()
    device.last_seen = timezone.now()
    device.save(update_fields=["last_seen"])
    settings = PortalSettings.objects.first()
    return JsonResponse(
        {
            "device_id": device.device_id,
            "device_name": device.name,
            "room": device.room.identifier if device.room else None,
            "property": {
                "name": settings.property_name if settings else "",
                "location": settings.property_location if settings else "",
            },
            "payment_details": {
                "bank_name": settings.bank_name if settings else "",
                "account_name": settings.account_name if settings else "",
                "account_number": settings.account_number if settings else "",
            },
        }
    )


@csrf_exempt
@require_http_methods(["GET", "OPTIONS"])
def device_menu(request):
    if request.method == "OPTIONS":
        return JsonResponse({}, status=204)
    device = _device_from_id(request.headers.get("X-Device-ID", ""))
    if not device:
        return _device_error()
    device.last_seen = timezone.now()
    device.save(update_fields=["last_seen"])
    items = MenuItem.objects.filter(available=True).order_by("department", "category", "name")
    return JsonResponse({"items": [_menu_item_payload(request, item) for item in items]})


@require_http_methods(["GET"])
def menu_image(request, item_id):
    item = MenuItem.objects.filter(available=True, pk=item_id).only("image_url").first()
    if item is None or not item.image_url:
        return HttpResponse("Menu image not found.", status=404)

    supabase_url = urlsplit(settings.SUPABASE_URL)
    image_url = urlsplit(item.image_url)
    public_bucket_prefix = (
        f"/storage/v1/object/public/{quote(settings.SUPABASE_STORAGE_BUCKET, safe='')}/"
    )
    if (
        supabase_url.scheme != "https"
        or not supabase_url.netloc
        or image_url.scheme != "https"
        or image_url.netloc.lower() != supabase_url.netloc.lower()
        or not image_url.path.startswith(public_bucket_prefix)
        or image_url.query
        or image_url.fragment
    ):
        return HttpResponse("Stored menu image URL is invalid.", status=502)

    try:
        image_request = Request(
            item.image_url,
            headers={"Accept": ", ".join(MENU_IMAGE_TYPES)},
        )
        with urlopen(image_request, timeout=15) as response:
            content_type = response.headers.get_content_type()
            if content_type not in MENU_IMAGE_TYPES:
                return HttpResponse(
                    "Stored menu image has an unsupported format.", status=502
                )
            image = response.read(MAX_MENU_IMAGE_BYTES + 1)
    except HTTPError:
        return HttpResponse("Menu image storage rejected the request.", status=502)
    except (URLError, TimeoutError):
        return HttpResponse("Menu image storage is unavailable.", status=502)

    if len(image) > MAX_MENU_IMAGE_BYTES:
        return HttpResponse("Stored menu image exceeds the size limit.", status=502)

    result = HttpResponse(image, content_type=content_type)
    result["Cache-Control"] = "public, max-age=3600"
    result["X-Content-Type-Options"] = "nosniff"
    return result


@csrf_exempt
@require_http_methods(["GET", "OPTIONS"])
def device_services(request):
    if request.method == "OPTIONS":
        return JsonResponse({}, status=204)
    device = _device_from_id(request.headers.get("X-Device-ID", ""))
    if not device:
        return _device_error()
    services = ServiceOption.objects.filter(active=True).order_by(
        "department", "name"
    )
    return JsonResponse(
        {
            "services": [
                {
                    "id": service.pk,
                    "name": service.name,
                    "department": service.department,
                    "description": service.description,
                }
                for service in services
            ]
        }
    )


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def create_order(request):
    if request.method == "OPTIONS":
        return JsonResponse({}, status=204)
    data, error = _json_body(request)
    if error:
        return error
    device = _device_from_id(data.get("device_id"))
    if not device:
        return _device_error()
    sender_name = data.get("sender_name")
    requested_items = data.get("items")
    if not isinstance(sender_name, str) or not sender_name.strip():
        return JsonResponse({"error": "Bank transfer sender name is required."}, status=400)
    if not isinstance(requested_items, list) or not requested_items:
        return JsonResponse({"error": "Order must contain at least one item."}, status=400)

    quantities = {}
    for entry in requested_items:
        if not isinstance(entry, dict):
            return JsonResponse({"error": "Each item must include an item ID and quantity."}, status=400)
        item_id, quantity = entry.get("item_id"), entry.get("quantity")
        if (
            isinstance(item_id, bool)
            or not isinstance(item_id, int)
            or isinstance(quantity, bool)
            or not isinstance(quantity, int)
            or not 1 <= quantity <= 50
        ):
            return JsonResponse({"error": "Each quantity must be between 1 and 50."}, status=400)
        quantities[item_id] = quantities.get(item_id, 0) + quantity
        if quantities[item_id] > 50:
            return JsonResponse({"error": "A maximum of 50 units per menu item is allowed."}, status=400)

    items = list(MenuItem.objects.filter(pk__in=quantities, available=True))
    if len(items) != len(quantities):
        return JsonResponse({"error": "One or more items are unavailable."}, status=400)

    subtotal = sum(
        (item.price * quantities[item.pk] for item in items),
        start=Decimal("0.00"),
    )
    service_charge = (subtotal * Decimal("0.10")).quantize(
        Decimal("0.01"), rounding=ROUND_HALF_UP
    )
    expected_total = data.get("expected_total")
    if isinstance(expected_total, bool) or not isinstance(expected_total, (int, str)):
        return JsonResponse({"error": "Expected order total is required."}, status=400)
    try:
        paid_total = Decimal(str(expected_total))
    except (InvalidOperation, ValueError):
        return JsonResponse({"error": "Expected order total is invalid."}, status=400)
    if not paid_total.is_finite() or paid_total != subtotal + service_charge:
        return JsonResponse(
            {
                "error": "The menu total changed. Review the updated cart before ordering.",
                "total": str(subtotal + service_charge),
            },
            status=409,
        )

    with transaction.atomic():
        order = Order.objects.create(
            device=device,
            sender_name=sender_name.strip()[:120],
            payment_status="review",
            service_charge=service_charge,
        )
        for item in items:
            OrderLine.objects.create(
                order=order,
                menu_item=item,
                item_name=item.name,
                unit_price=item.price,
                quantity=quantities[item.pk],
                preparation_minutes=item.preparation_minutes,
            )
        _record_routing_attempts(order=order)
    return JsonResponse(
        {
            "order_number": order.order_number,
            "status": order.status,
            "payment_status": order.payment_status,
            "total": str(order.total),
            "estimated_minutes": order.estimated_minutes,
            "items": [
                {
                    "name": line.item_name,
                    "quantity": line.quantity,
                    "preparation_minutes": line.preparation_minutes,
                }
                for line in order.lines.all()
            ],
        },
        status=201,
    )


@csrf_exempt
@require_http_methods(["GET", "OPTIONS"])
def order_status(request, order_number):
    if request.method == "OPTIONS":
        return JsonResponse({}, status=204)
    device = _device_from_id(request.headers.get("X-Device-ID", ""))
    if not device:
        return _device_error()
    order = Order.objects.filter(order_number=order_number, device=device).first()
    if not order:
        return JsonResponse({"error": "Order not found for this device."}, status=404)
    return JsonResponse(
        {
            "order_number": order.order_number,
            "status": order.status,
            "payment_status": order.payment_status,
            "estimated_minutes": order.estimated_minutes,
            "updated_at": order.updated_at.isoformat(),
        }
    )


@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def create_service_request(request):
    if request.method == "OPTIONS":
        return JsonResponse({}, status=204)
    data, error = _json_body(request)
    if error:
        return error
    device = _device_from_id(data.get("device_id"))
    if not device:
        return _device_error()
    service_id = data.get("service_id")
    details = data.get("details", "")
    if not isinstance(details, str):
        return JsonResponse({"error": "Request details must be text."}, status=400)
    service = ServiceOption.objects.filter(pk=service_id, active=True).first()
    if service_id and not service:
        return JsonResponse({"error": "Service is unavailable."}, status=400)
    request_record = ServiceRequest.objects.create(
        device=device,
        room_identifier=device.room.identifier if device.room else "",
        service=service,
        details=details.strip()[:2000],
    )
    _record_routing_attempts(service_request=request_record)
    return JsonResponse(
        {"request_id": str(request_record.request_number), "status": request_record.status},
        status=201,
    )
