import base64
import json
from decimal import Decimal, InvalidOperation
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlencode, urlsplit
from urllib.request import Request, urlopen

from django.conf import settings
from django.db import transaction
from django.db.models import Q
from django.http import HttpResponse, JsonResponse
from django.middleware.csrf import get_token
from django.urls import reverse
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt, csrf_protect
from django.views.decorators.http import require_GET, require_http_methods, require_POST

from .models import (
    Device,
    MenuItem,
    Order,
    OrderLine,
    StaffProfile,
    StaffPushSubscription,
    ROUTING_DEPARTMENTS,
    ServiceOption,
    ServiceRequest,
    WhatsAppAttempt,
)
from .push_notifications import schedule_staff_pushes
from .routing import _record_routing_attempts
from .whatsapp_links import order_notification_text, whatsapp_link

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
        Device.objects.select_related("room", "property")
        .filter(device_id=device_id, active=True, property__is_active=True)
        .filter(Q(room__isnull=True) | Q(room__active=True))
        .first()
    )


def _device_error():
    return JsonResponse({"error": "Device ID is invalid or inactive."}, status=403)


def _menu_item_payload(request, item, device):
    image_url = None
    if item.image_url:
        image_url = request.build_absolute_uri(
            f"{reverse('api_menu_image', args=[item.pk])}?"
            f"{urlencode({'device_id': device.device_id})}"
        )
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
        "image_url": image_url,
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
    settings = device.property
    return JsonResponse(
        {
            "device_id": device.device_id,
            "device_name": device.name,
            "room": device.room.identifier if device.room else None,
            "property": {
                "name": settings.property_name,
                "location": settings.property_location,
            },
            "payment_details": {
                "bank_name": settings.bank_name,
                "account_name": settings.account_name,
                "account_number": settings.account_number,
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
    items = MenuItem.objects.filter(
        property=device.property, available=True
    ).order_by("department", "category", "name")
    return JsonResponse(
        {"items": [_menu_item_payload(request, item, device) for item in items]}
    )


@require_http_methods(["GET"])
def menu_image(request, item_id):
    device = _device_from_id(request.GET.get("device_id", ""))
    if not device:
        return _device_error()
    item = MenuItem.objects.filter(
        property=device.property, available=True, pk=item_id
    ).only("image_url").first()
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
    services = ServiceOption.objects.filter(
        property=device.property, active=True
    ).order_by("department", "name")
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

    items = list(
        MenuItem.objects.filter(
            property=device.property, pk__in=quantities, available=True
        )
    )
    if len(items) != len(quantities):
        return JsonResponse({"error": "One or more items are unavailable."}, status=400)

    subtotal = sum(
        (item.price * quantities[item.pk] for item in items),
        start=Decimal("0.00"),
    )
    expected_total = data.get("expected_total")
    if isinstance(expected_total, bool) or not isinstance(expected_total, (int, str)):
        return JsonResponse({"error": "Expected order total is required."}, status=400)
    try:
        paid_total = Decimal(str(expected_total))
    except (InvalidOperation, ValueError):
        return JsonResponse({"error": "Expected order total is invalid."}, status=400)
    if not paid_total.is_finite() or paid_total != subtotal:
        return JsonResponse(
            {
                "error": "The menu total changed. Review the updated cart before ordering.",
                "total": str(subtotal),
            },
            status=409,
        )

    with transaction.atomic():
        order = Order.objects.create(
            property=device.property,
            device=device,
            sender_name=sender_name.strip()[:120],
            payment_status="review",
            service_charge=Decimal("0.00"),
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
        schedule_staff_pushes(order=order)
    whatsapp_messages = []
    for attempt in WhatsAppAttempt.objects.select_related("staff__user").filter(
        order=order
    ):
        active_staff = (
            attempt.staff
            and attempt.staff.active
            and attempt.staff.user.is_active
        )
        whatsapp_url = (
            whatsapp_link(
                attempt.recipient_number,
                order_notification_text(order, attempt.department),
            )
            if active_staff and attempt.status in {"demo", "disabled"}
            else ""
        )
        whatsapp_messages.append(
            {
                "department": dict(ROUTING_DEPARTMENTS).get(
                    attempt.department, attempt.department.title()
                ),
                "staff_name": (
                    attempt.staff.user.get_full_name()
                    or attempt.staff.user.get_username()
                    if attempt.staff
                    else ""
                ),
                "status": attempt.status,
                "detail": (
                    "Open WhatsApp and tap Send. No message is sent automatically."
                    if whatsapp_url
                    else (
                        "Assigned staff WhatsApp number is invalid."
                        if attempt.status in {"demo", "disabled"} and active_staff
                        else attempt.detail
                    )
                ),
                "whatsapp_url": whatsapp_url,
            }
        )
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
            "whatsapp_messages": whatsapp_messages,
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
    service = ServiceOption.objects.filter(
        property=device.property, pk=service_id, active=True
    ).first()
    if service_id and not service:
        return JsonResponse({"error": "Service is unavailable."}, status=400)
    request_record = ServiceRequest.objects.create(
        property=device.property,
        device=device,
        room_identifier=device.room.identifier if device.room else "",
        service=service,
        details=details.strip()[:2000],
    )
    _record_routing_attempts(service_request=request_record)
    schedule_staff_pushes(service_request=request_record)
    return JsonResponse(
        {"request_id": str(request_record.request_number), "status": request_record.status},
        status=201,
    )


@require_GET
def staff_session(request):
    profile, error = _assigned_staff_profile(request)
    if error:
        return error
    return JsonResponse(
        {
            "username": request.user.get_username(),
            "name": request.user.get_full_name() or request.user.get_username(),
            "department": profile.departments or profile.get_role_display(),
            "push_enabled": _web_push_is_configured(),
            "push_public_key": settings.WEB_PUSH_VAPID_PUBLIC_KEY,
            "csrf_token": get_token(request),
        }
    )


@require_GET
def staff_notifications(request):
    profile, error = _assigned_staff_profile(request)
    if error:
        return error
    attempts = (
        WhatsAppAttempt.objects.filter(staff=profile)
        .select_related(
            "order",
            "service_request",
            "service_request__service",
            "service_request__device",
        )
        .prefetch_related("order__lines__menu_item")
        .order_by("-created_at")[:50]
    )
    notifications = []
    for attempt in attempts:
        if attempt.order_id:
            order = attempt.order
            order_lines = [
                {
                    "name": line.item_name,
                    "quantity": line.quantity,
                }
                for line in order.lines.all()
                if line.menu_item_id and line.menu_item.department == attempt.department
            ]
            notifications.append(
                {
                    "id": attempt.pk,
                    "type": "order",
                    "department": attempt.get_department_display(),
                    "title": f"New {attempt.get_department_display()} order",
                    "order_number": order.order_number,
                    "room": order.room_identifier or "Unassigned",
                    "sender_name": order.sender_name,
                    "total": str(order.total),
                    "status": order.get_status_display(),
                    "payment_status": order.get_payment_status_display(),
                    "items": order_lines,
                    "details": "",
                    "created_at": attempt.created_at.isoformat(),
                }
            )
        elif attempt.service_request_id:
            service_request = attempt.service_request
            notifications.append(
                {
                    "id": attempt.pk,
                    "type": "service",
                    "department": attempt.get_department_display(),
                    "title": service_request.service.name
                    if service_request.service_id
                    else "Guest service request",
                    "order_number": str(service_request.request_number),
                    "room": service_request.room_identifier or "Unassigned",
                    "sender_name": "",
                    "total": "0",
                    "status": service_request.get_status_display(),
                    "payment_status": "",
                    "items": [],
                    "details": service_request.details,
                    "created_at": attempt.created_at.isoformat(),
                }
            )
    return JsonResponse({"notifications": notifications})


@require_POST
@csrf_protect
def staff_push_subscription(request):
    profile, error = _assigned_staff_profile(request)
    if error:
        return error
    if not _web_push_is_configured():
        return JsonResponse(
            {"error": "Browser push is not configured for this portal."},
            status=503,
        )
    data, error = _json_body(request)
    if error:
        return error
    subscription = data.get("subscription")
    if not isinstance(subscription, dict):
        return JsonResponse({"error": "Push subscription is required."}, status=400)
    endpoint = subscription.get("endpoint")
    keys = subscription.get("keys")
    if not isinstance(endpoint, str) or not isinstance(keys, dict):
        return JsonResponse({"error": "Push subscription is invalid."}, status=400)
    try:
        endpoint_parts = urlsplit(endpoint)
        host = (endpoint_parts.hostname or "").lower().rstrip(".")
        endpoint_port = endpoint_parts.port
    except ValueError:
        return JsonResponse({"error": "Push subscription is invalid."}, status=400)
    allowed_hosts = (
        host == "fcm.googleapis.com"
        or host.endswith(".push.services.mozilla.com")
        or host.endswith(".push.apple.com")
        or host.endswith(".notify.windows.com")
    )
    p256dh, auth = keys.get("p256dh"), keys.get("auth")
    if (
        endpoint_parts.scheme != "https"
        or endpoint_port not in (None, 443)
        or endpoint_parts.username
        or endpoint_parts.password
        or not allowed_hosts
        or len(endpoint) > 2048
        or not isinstance(p256dh, str)
        or not isinstance(auth, str)
        or len(p256dh) > 128
        or len(auth) > 64
    ):
        return JsonResponse({"error": "Push subscription is invalid."}, status=400)
    try:
        public_key = _decode_push_key(p256dh)
        auth_key = _decode_push_key(auth)
    except (ValueError, base64.binascii.Error):
        return JsonResponse({"error": "Push subscription keys are invalid."}, status=400)
    if len(public_key) != 65 or len(auth_key) != 16:
        return JsonResponse({"error": "Push subscription keys are invalid."}, status=400)

    StaffPushSubscription.objects.update_or_create(
        endpoint=endpoint,
        defaults={"staff": profile, "p256dh": p256dh, "auth": auth},
    )
    return JsonResponse({"status": "enabled"})


def _assigned_staff_profile(request):
    if not request.user.is_authenticated:
        return None, JsonResponse({"error": "Sign in to view staff notifications."}, status=401)
    profile = (
        StaffProfile.objects.select_related("property")
        .filter(user=request.user, active=True, property__is_active=True)
        .first()
    )
    if profile is None:
        return None, JsonResponse(
            {"error": "This account is not an active staff account."}, status=403
        )
    return profile, None


def _decode_push_key(value):
    padded = value + "=" * (-len(value) % 4)
    return base64.b64decode(padded.encode("ascii"), altchars=b"-_", validate=True)


def _web_push_is_configured():
    return all(
        (
            settings.WEB_PUSH_VAPID_PUBLIC_KEY,
            settings.WEB_PUSH_VAPID_PRIVATE_KEY_B64,
            settings.WEB_PUSH_VAPID_SUBJECT,
        )
    )
