from datetime import date
from decimal import Decimal
from io import BytesIO

import qrcode
from qrcode.image.svg import SvgPathImage
from django.conf import settings
from django.contrib import messages
from django.contrib.auth import get_user_model, login
from django.contrib.auth.decorators import login_required, user_passes_test
from django.db import transaction
from django.db.models import DecimalField, ExpressionWrapper, F, Prefetch, Sum
from django.http import HttpResponse, HttpResponseNotAllowed
from django.shortcuts import get_object_or_404, redirect, render
from django.urls import reverse
from django.utils import timezone
from django.views.decorators.http import require_POST

from .forms import (
    DeviceForm,
    ManagerSignupForm,
    MenuItemForm,
    PortalSettingsForm,
    RoomForm,
    ServiceOptionForm,
    StaffCreateForm,
)
from .models import (
    Device,
    MenuItem,
    Order,
    OrderLine,
    PortalSettings,
    Room,
    ServiceOption,
    ServiceRequest,
    StaffProfile,
    ShiftAssignment,
    SHIFT_CHOICES,
    ROUTING_DEPARTMENTS,
    WhatsAppAttempt,
)
from .menu_images import MenuImageStorageError, store_menu_image
from .qr_codes import guest_order_qr_url
from .whatsapp_links import order_notification_text, whatsapp_link

User = get_user_model()


def _admin_only(user):
    return user.is_superuser or StaffProfile.objects.filter(
        user=user, role="admin", active=True, property__is_active=True
    ).exists()


def _manager_only(user):
    return user.is_superuser or StaffProfile.objects.filter(
        user=user, role="manager", active=True, property__is_active=True
    ).exists()


def _can_manage_staff(user):
    return _admin_only(user)


def _can_manage_configuration(user):
    return _admin_only(user)


def _property_for_user(user):
    if user.is_superuser:
        return PortalSettings.objects.order_by("pk").first()
    profile = (
        StaffProfile.objects.filter(
            user=user, active=True, property__is_active=True
        )
        .select_related("property")
        .first()
    )
    return profile.property if profile else None


def _for_user_property(queryset, user):
    if user.is_superuser:
        return queryset
    property_record = _property_for_user(user)
    if property_record is None:
        return queryset.none()
    return queryset.filter(property=property_record)


def _can_manage_operations(user):
    return user.is_superuser or StaffProfile.objects.filter(
        user=user, role="admin", active=True, property__is_active=True
    ).exists()


def _base(request):
    property_record = _property_for_user(request.user)
    return {
        "portal_settings": property_record,
        "can_manage_operations": _can_manage_operations(request.user),
        "can_manage_configuration": _can_manage_configuration(request.user),
        "can_manage_staff": _can_manage_staff(request.user),
        "can_manage_settings": _manager_only(request.user),
    }


def _dashboard_whatsapp_activity(user):
    attempts = (
        _for_user_property(
            WhatsAppAttempt.objects.filter(order__isnull=False), user
        )
        .select_related("order", "order__device", "staff__user")
        .prefetch_related("order__lines__menu_item")[:15]
    )
    activity = []
    for attempt in attempts:
        order = attempt.order
        attempt.department_lines = [
            line
            for line in order.lines.all()
            if line.menu_item_id and line.menu_item.department == attempt.department
        ]
        attempt.sender_name = order.sender_name
        attempt.whatsapp_url = (
            whatsapp_link(
                attempt.recipient_number,
                order_notification_text(order, attempt.department),
            )
            if attempt.status == "demo"
            else ""
        )
        activity.append(attempt)
    return activity


def manager_signup(request):
    if request.user.is_authenticated:
        return redirect("dashboard")
    form = ManagerSignupForm(request.POST or None)
    if request.method == "POST" and form.is_valid():
        with transaction.atomic():
            user = form.save()
            property_settings = PortalSettings.objects.create(
                property_name=form.cleaned_data["property_name"],
                property_location=form.cleaned_data["property_location"],
            )
            StaffProfile.objects.create(
                user=user,
                role="manager",
                property=property_settings,
                phone_number=form.cleaned_data["phone_number"],
            )
        login(request, user)
        messages.success(
            request,
            "Manager account and property details created.",
        )
        return redirect("dashboard")
    return render(request, "manager_signup.html", {"form": form})


def _revenue_for_orders(orders):
    confirmed_orders = orders.filter(payment_status="confirmed")
    item_revenue = (
        OrderLine.objects.filter(order__in=confirmed_orders)
        .aggregate(
            value=Sum(
                ExpressionWrapper(
                    F("unit_price") * F("quantity"),
                    output_field=DecimalField(max_digits=12, decimal_places=2),
                )
            )
        )["value"]
        or Decimal("0.00")
    )
    service_charges = confirmed_orders.aggregate(value=Sum("service_charge"))[
        "value"
    ] or Decimal("0.00")
    return item_revenue + service_charges


@login_required
def dashboard(request):
    if not _can_manage_operations(request.user):
        return render(
            request,
            "portal/dashboard.html",
            {
                "notification_only": True,
                **_base(request),
            },
        )
    today = timezone.localdate()
    orders = _for_user_property(
        Order.objects.filter(created_at__date=today), request.user
    )
    service_requests = _for_user_property(ServiceRequest.objects.all(), request.user)
    context = {
        "orders_today": orders.count(),
        "revenue_today": _revenue_for_orders(orders),
        "service_requests": service_requests.exclude(
            status__in=["completed", "cancelled"]
        ).count(),
        "awaiting_payment": orders.filter(payment_status="review").count(),
        "active_orders": _for_user_property(Order.objects.all(), request.user).exclude(
            status__in=["completed", "cancelled"]
        ).select_related("device")[:8],
        "active_requests": service_requests.exclude(
            status__in=["completed", "cancelled"]
        ).select_related("device", "service")[:8],
        "whatsapp_activity": _dashboard_whatsapp_activity(request.user),
        **_base(request),
    }
    return render(request, "portal/dashboard.html", context)


@login_required
@user_passes_test(lambda user: user.is_superuser, login_url="dashboard")
def command_center(request):
    manager_profiles = StaffProfile.objects.filter(
        role="manager"
    ).select_related("user").order_by("user__first_name", "user__last_name")
    properties = PortalSettings.objects.prefetch_related(
        Prefetch(
            "staff_profiles",
            queryset=manager_profiles,
            to_attr="command_center_managers",
        )
    ).order_by("-pk")
    return render(
        request,
        "portal/command_center.html",
        {
            "properties": properties,
            "property_count": properties.count(),
            "active_count": properties.filter(is_active=True).count(),
            "confirmed_count": properties.filter(
                subscription_confirmed=True
            ).count(),
        },
    )


@login_required
@user_passes_test(lambda user: user.is_superuser, login_url="dashboard")
@require_POST
def command_center_action(request, property_id):
    property_record = get_object_or_404(PortalSettings, pk=property_id)
    action = request.POST.get("action")
    if action == "confirm_subscription":
        property_record.subscription_confirmed = True
        property_record.subscription_confirmed_at = timezone.now()
        property_record.save(
            update_fields=["subscription_confirmed", "subscription_confirmed_at", "updated_at"]
        )
        messages.success(request, f"Subscription confirmed for {property_record.property_name}.")
    elif action == "revoke_subscription":
        property_record.subscription_confirmed = False
        property_record.subscription_confirmed_at = None
        property_record.save(
            update_fields=["subscription_confirmed", "subscription_confirmed_at", "updated_at"]
        )
        messages.success(request, f"Subscription status reset for {property_record.property_name}.")
    elif action == "deactivate":
        property_record.is_active = False
        property_record.save(update_fields=["is_active", "updated_at"])
        messages.success(
            request,
            f"{property_record.property_name} was deactivated. Its records are retained.",
        )
    elif action == "reactivate":
        property_record.is_active = True
        property_record.save(update_fields=["is_active", "updated_at"])
        messages.success(request, f"{property_record.property_name} was reactivated.")
    else:
        return HttpResponse("Choose a valid command-center action.", status=400)
    return redirect("command_center")


@login_required
@user_passes_test(_can_manage_operations, login_url="dashboard")
def dashboard_activity(request):
    return render(
        request,
        "portal/partials/dashboard_activity.html",
        {"whatsapp_activity": _dashboard_whatsapp_activity(request.user)},
    )


@login_required
@user_passes_test(_can_manage_operations, login_url="dashboard")
def order_list(request):
    orders = _for_user_property(
        Order.objects.select_related("device").prefetch_related("lines"),
        request.user,
    )
    status = request.GET.get("status", "")
    department = request.GET.get("department", "")
    if status:
        orders = orders.filter(status=status)
    if department in {"kitchen", "bar"}:
        orders = orders.filter(lines__menu_item__department=department).distinct()
    return render(
        request,
        "portal/order_list.html",
        {
            "orders": orders[:100],
            "statuses": Order.ORDER_STATUSES,
            "status_filter": status,
            "department_filter": department,
            **_base(request),
        },
    )


@login_required
@user_passes_test(_can_manage_operations, login_url="dashboard")
def order_detail(request, order_id):
    order = get_object_or_404(
        _for_user_property(
            Order.objects.select_related(
                "device", "payment_confirmed_by"
            ).prefetch_related("lines"),
            request.user,
        ),
        pk=order_id,
    )
    return render(
        request, "portal/order_detail.html", {"order": order, **_base(request)}
    )


@login_required
@user_passes_test(_can_manage_operations, login_url="dashboard")
@require_POST
def update_order(request, order_id):
    order = get_object_or_404(
        _for_user_property(Order.objects.all(), request.user), pk=order_id
    )
    action = request.POST.get("action")
    if action == "confirm_payment":
        if order.payment_status != "review":
            messages.error(request, "Only payments awaiting verification can be confirmed.")
        else:
            order.payment_status = "confirmed"
            order.payment_confirmed_by = request.user
            order.payment_confirmed_at = timezone.now()
            order.save(
                update_fields=[
                    "payment_status",
                    "payment_confirmed_by",
                    "payment_confirmed_at",
                    "updated_at",
                ]
            )
            messages.success(request, "Payment confirmed.")
    elif action == "reject_payment":
        if order.payment_status != "review":
            messages.error(request, "Only payments awaiting verification can be rejected.")
        else:
            order.payment_status = "rejected"
            order.save(update_fields=["payment_status", "updated_at"])
            messages.success(request, "Payment marked as rejected.")
    elif action == "update_status":
        new_status = request.POST.get("status")
        if new_status not in dict(Order.ORDER_STATUSES):
            messages.error(request, "Choose a valid order status.")
        else:
            order.status = new_status
            order.save(update_fields=["status", "updated_at"])
            messages.success(request, "Order status updated.")
    else:
        return HttpResponseNotAllowed(["POST"])
    return redirect("order_detail", order_id=order.pk)


@login_required
@user_passes_test(_can_manage_operations, login_url="dashboard")
def payment_list(request):
    orders = _for_user_property(
        Order.objects.select_related("device").prefetch_related("lines"),
        request.user,
    )
    payment_status = request.GET.get("status", "")
    if payment_status in dict(Order.PAYMENT_STATUSES):
        orders = orders.filter(payment_status=payment_status)
    return render(
        request,
        "portal/payment_list.html",
        {
            "orders": orders[:100],
            "payment_statuses": Order.PAYMENT_STATUSES,
            "status_filter": payment_status,
            **_base(request),
        },
    )


@login_required
@user_passes_test(_can_manage_operations, login_url="dashboard")
def service_request_list(request):
    requests = _for_user_property(
        ServiceRequest.objects.select_related("device", "service"), request.user
    )
    return render(
        request,
        "portal/service_requests.html",
        {"requests": requests[:100], "statuses": ServiceRequest.STATUSES, **_base(request)},
    )


@login_required
@user_passes_test(_can_manage_operations, login_url="dashboard")
@require_POST
def update_service_request(request, request_id):
    service_request = get_object_or_404(
        _for_user_property(ServiceRequest.objects.all(), request.user), pk=request_id
    )
    status = request.POST.get("status")
    if status not in dict(ServiceRequest.STATUSES):
        messages.error(request, "Choose a valid request status.")
    else:
        service_request.status = status
        service_request.save(update_fields=["status", "updated_at"])
        messages.success(request, "Service request updated.")
    return redirect("service_requests")


@login_required
@user_passes_test(_can_manage_operations, login_url="dashboard")
def handler_view(request):
    orders = _for_user_property(
        Order.objects.exclude(status__in=["completed", "cancelled"]).prefetch_related(
            "lines"
        ),
        request.user,
    )
    requests = _for_user_property(
        ServiceRequest.objects.exclude(
            status__in=["completed", "cancelled"]
        ).select_related("service", "device"),
        request.user,
    )
    return render(
        request,
        "portal/handler.html",
        {"orders": orders[:50], "requests": requests[:50], **_base(request)},
    )


@login_required
@user_passes_test(_can_manage_configuration, login_url="dashboard")
def menu_list(request, department):
    if department not in {"kitchen", "bar"}:
        return redirect("menu_list", department="kitchen")
    items = _for_user_property(
        MenuItem.objects.filter(department=department), request.user
    )
    return render(
        request,
        "portal/menu_list.html",
        {"items": items, "department": department, **_base(request)},
    )


@login_required
@user_passes_test(_can_manage_configuration, login_url="dashboard")
def menu_create(request):
    property_record = _property_for_user(request.user)
    if property_record is None:
        return HttpResponse("Create property settings before adding menu items.", status=403)
    initial = {"department": request.GET.get("department", "kitchen")}
    form = MenuItemForm(
        request.POST or None,
        request.FILES or None,
        initial=initial,
        property=property_record,
    )
    if request.method == "POST" and form.is_valid():
        item = form.save(commit=False)
        try:
            if form.cleaned_data["image_file"]:
                item.image_url = store_menu_image(form.cleaned_data["image_file"])
        except MenuImageStorageError as error:
            form.add_error("image_file", str(error))
        else:
            item.save()
            messages.success(request, f"{item.name} added to the menu.")
            return redirect("menu_list", department=item.department)
    return render(
        request,
        "portal/form.html",
        {"form": form, "title": "Add Menu Item", "cancel_url": "menu_list", **_base(request)},
    )


@login_required
@user_passes_test(_can_manage_configuration, login_url="dashboard")
def menu_edit(request, item_id):
    item = get_object_or_404(
        _for_user_property(MenuItem.objects.all(), request.user), pk=item_id
    )
    form = MenuItemForm(
        request.POST or None,
        request.FILES or None,
        instance=item,
        property=item.property,
    )
    if request.method == "POST" and form.is_valid():
        item = form.save(commit=False)
        try:
            if form.cleaned_data["image_file"]:
                item.image_url = store_menu_image(form.cleaned_data["image_file"])
        except MenuImageStorageError as error:
            form.add_error("image_file", str(error))
        else:
            item.save()
            messages.success(request, "Menu item updated.")
            return redirect("menu_list", department=item.department)
    return render(
        request,
        "portal/form.html",
        {
            "form": form,
            "title": f"Edit {item.name}",
            "cancel_url": "menu_list",
            "cancel_department": item.department,
            **_base(request),
        },
    )


@login_required
@user_passes_test(_can_manage_configuration, login_url="dashboard")
@require_POST
def menu_toggle(request, item_id):
    item = get_object_or_404(
        _for_user_property(MenuItem.objects.all(), request.user), pk=item_id
    )
    item.available = not item.available
    item.save(update_fields=["available"])
    messages.success(request, f"{item.name} availability updated.")
    return redirect("menu_list", department=item.department)


@login_required
@user_passes_test(_can_manage_configuration, login_url="dashboard")
def services_list(request):
    property_record = _property_for_user(request.user)
    if property_record is None:
        return HttpResponse("Create property settings before adding services.", status=403)
    options = _for_user_property(ServiceOption.objects.all(), request.user)
    form = ServiceOptionForm(
        request.POST or None, property=property_record
    )
    if request.method == "POST" and form.is_valid():
        form.save()
        messages.success(request, "Service option added.")
        return redirect("services")
    return render(
        request,
        "portal/services.html",
        {"services": options, "form": form, **_base(request)},
    )


@login_required
@user_passes_test(_can_manage_configuration, login_url="dashboard")
def service_edit(request, service_id):
    service = get_object_or_404(
        _for_user_property(ServiceOption.objects.all(), request.user), pk=service_id
    )
    form = ServiceOptionForm(
        request.POST or None, instance=service, property=service.property
    )
    if request.method == "POST" and form.is_valid():
        service = form.save()
        messages.success(request, f"{service.name} updated.")
        return redirect("services")
    return render(
        request,
        "portal/form.html",
        {"form": form, "title": f"Edit {service.name}", "cancel_url": "services", **_base(request)},
    )


@login_required
@user_passes_test(_can_manage_configuration, login_url="dashboard")
@require_POST
def service_toggle(request, service_id):
    service = get_object_or_404(
        _for_user_property(ServiceOption.objects.all(), request.user), pk=service_id
    )
    service.active = not service.active
    service.save(update_fields=["active"])
    messages.success(request, f"{service.name} availability updated.")
    return redirect("services")


@login_required
@user_passes_test(_can_manage_configuration, login_url="dashboard")
def room_list(request):
    return render(
        request,
        "portal/room_list.html",
        {
            "rooms": _for_user_property(
                Room.objects.prefetch_related("devices"), request.user
            ),
            **_base(request),
        },
    )


@login_required
@user_passes_test(_can_manage_configuration, login_url="dashboard")
def room_create(request):
    property_record = _property_for_user(request.user)
    if property_record is None:
        return HttpResponse("Create property settings before adding rooms.", status=403)
    form = RoomForm(request.POST or None, property=property_record)
    if request.method == "POST" and form.is_valid():
        room = form.save()
        room.ensure_ordering_device()
        messages.success(request, "Room or table added and its ordering QR is ready.")
        return redirect("rooms")
    return render(
        request,
        "portal/form.html",
        {"form": form, "title": "Add Room / Table", "cancel_url": "rooms", **_base(request)},
    )


@login_required
@user_passes_test(_can_manage_configuration, login_url="dashboard")
def room_edit(request, room_id):
    room = get_object_or_404(
        _for_user_property(Room.objects.all(), request.user), pk=room_id
    )
    form = RoomForm(request.POST or None, instance=room, property=room.property)
    if request.method == "POST" and form.is_valid():
        room = form.save()
        room.ensure_ordering_device()
        messages.success(request, "Room or table updated.")
        return redirect("rooms")
    return render(
        request,
        "portal/form.html",
        {"form": form, "title": f"Edit {room.identifier}", "cancel_url": "rooms", **_base(request)},
    )


@login_required
def room_qr(request, room_id):
    room = get_object_or_404(
        _for_user_property(Room.objects.all(), request.user), pk=room_id
    )
    if not _admin_only(request.user):
        return HttpResponse("Only administrators can manage QR codes.", status=403)
    if request.method == "POST":
        device = room.ensure_ordering_device()
        if device is None:
            messages.error(request, "Activate this room or table before generating its QR.")
            return redirect("room_qr", room_id=room.pk)
        messages.success(request, f"QR code ready for {room.identifier}.")
        return redirect("room_qr", room_id=room.pk)
    if request.method != "GET":
        return HttpResponseNotAllowed(["GET", "POST"])
    return render(
        request,
        "portal/room_qr.html",
        {
            "room": room,
            "device": room.active_qr_device,
            "qr_url": (
                guest_order_qr_url(request, room.active_qr_device.device_id)
                if room.active_qr_device
                else None
            ),
            **_base(request),
        },
    )


@login_required
@user_passes_test(_can_manage_configuration, login_url="dashboard")
def room_qr_image(request, room_id):
    room = get_object_or_404(
        _for_user_property(Room.objects.all(), request.user), pk=room_id
    )
    device = room.active_qr_device
    if device is None:
        return HttpResponse(
            "Generate a QR code for this room or table first.", status=404
        )

    qr_url = guest_order_qr_url(request, device.device_id)
    image = qrcode.make(qr_url, image_factory=SvgPathImage)
    output = BytesIO()
    image.save(output)
    response = HttpResponse(output.getvalue(), content_type="image/svg+xml")
    response["Cache-Control"] = "private, max-age=300"
    return response


def guest_order(request):
    return render(
        request,
        "portal/guest_order.html",
        {
            "guest_config": {
                "device_id": request.GET.get("device_id", ""),
                "session_url": reverse("api_device_session"),
                "menu_url": reverse("api_device_menu"),
                "orders_url": reverse("api_create_order"),
            }
        },
    )


@login_required
@user_passes_test(_can_manage_configuration, login_url="dashboard")
def device_list(request):
    return render(
        request,
        "portal/device_list.html",
        {
            "devices": _for_user_property(
                Device.objects.filter(is_qr_device=False).select_related("room"),
                request.user,
            ),
            **_base(request),
        },
    )


@login_required
@user_passes_test(_can_manage_configuration, login_url="dashboard")
def device_create(request):
    property_record = _property_for_user(request.user)
    if property_record is None:
        return HttpResponse("Create property settings before adding devices.", status=403)
    form = DeviceForm(request.POST or None, property=property_record)
    if request.method == "POST" and form.is_valid():
        device = form.save()
        messages.success(
            request,
            f"Device registered for {device.room.identifier} with system-assigned ID {device.device_id}.",
        )
        return redirect("devices")
    return render(
        request,
        "portal/form.html",
        {"form": form, "title": "Register Device", "cancel_url": "devices", **_base(request)},
    )


@login_required
@user_passes_test(_can_manage_configuration, login_url="dashboard")
def device_edit(request, device_id):
    device = get_object_or_404(
        _for_user_property(Device.objects.all(), request.user), pk=device_id
    )
    form = DeviceForm(
        request.POST or None, instance=device, property=device.property
    )
    if request.method == "POST" and form.is_valid():
        form.save()
        messages.success(request, "Device updated.")
        return redirect("devices")
    return render(
        request,
        "portal/form.html",
        {"form": form, "title": f"Edit {device.name}", "cancel_url": "devices", **_base(request)},
    )


@login_required
@user_passes_test(_can_manage_staff, login_url="dashboard")
def staff_list(request):
    staff = User.objects.filter(
        is_superuser=False, staff_profile__isnull=False
    ).select_related("staff_profile").order_by("first_name", "last_name", "username")
    if not request.user.is_superuser:
        staff = staff.filter(staff_profile__property=_property_for_user(request.user))
    return render(
        request,
        "portal/staff_list.html",
        {
            "staff_members": staff,
            "staff_count": staff.count(),
            "active_staff_count": staff.filter(
                is_active=True, staff_profile__active=True
            ).count(),
            **_base(request),
        },
    )


@login_required
@user_passes_test(_can_manage_staff, login_url="dashboard")
def staff_create(request):
    property_record = _property_for_user(request.user)
    if property_record is None:
        return HttpResponse("Create property settings before adding staff.", status=403)
    form = StaffCreateForm(
        request.POST or None,
        allowed_roles=StaffProfile.DEPARTMENT_STAFF_ROLES,
        property=property_record,
    )
    if request.method == "POST" and form.is_valid():
        user = form.save()
        messages.success(request, f"Staff account {user.username} created.")
        return redirect("staff")
    return render(
        request,
        "portal/form.html",
        {"form": form, "title": "Add Staff", "cancel_url": "staff", **_base(request)},
    )


@login_required
@user_passes_test(_manager_only, login_url="dashboard")
def staff_admin_create(request):
    property_record = _property_for_user(request.user)
    if property_record is None:
        return HttpResponse("Create property settings before adding staff.", status=403)
    form = StaffCreateForm(
        request.POST or None,
        fixed_role="admin",
        property=property_record,
    )
    if request.method == "POST" and form.is_valid():
        user = form.save()
        messages.success(request, f"Administrator account {user.username} created.")
        return redirect("dashboard")
    return render(
        request,
        "portal/form.html",
        {
            "form": form,
            "title": "Create Administrator Login",
            "cancel_url": "staff",
            **_base(request),
        },
    )


@login_required
@user_passes_test(_can_manage_staff, login_url="dashboard")
@require_POST
def staff_toggle(request, user_id):
    users = User.objects.filter(is_superuser=False, staff_profile__isnull=False)
    if not request.user.is_superuser:
        users = users.filter(staff_profile__property=_property_for_user(request.user))
    user = get_object_or_404(users, pk=user_id)
    target_profile = StaffProfile.objects.filter(user=user).first()
    if (
        target_profile
        and target_profile.role in {"manager", "admin"}
        and not _manager_only(request.user)
        and not request.user.is_superuser
    ):
        return HttpResponse(
            "Only a manager can change manager or administrator access.",
            status=403,
        )
    user.is_active = not user.is_active
    user.save(update_fields=["is_active"])
    target_profile.active = user.is_active
    target_profile.save(update_fields=["active"])
    messages.success(request, f"{user.username} access updated.")
    return redirect("staff")


@login_required
@user_passes_test(_can_manage_operations, login_url="dashboard")
def reports(request):
    selected_date = request.GET.get("date", "")
    try:
        report_date = (
            date.fromisoformat(selected_date) if selected_date else timezone.localdate()
        )
    except ValueError:
        report_date = timezone.localdate()
        messages.error(request, "Enter a valid report date.")
    orders = _for_user_property(
        Order.objects.filter(created_at__date=report_date), request.user
    )
    context = {
        "report_date": report_date,
        "total_orders": orders.count(),
        "revenue": _revenue_for_orders(orders),
        "completed": orders.filter(status="completed").count(),
        "cancelled": orders.filter(status="cancelled").count(),
        "kitchen": orders.filter(lines__menu_item__department="kitchen").distinct().count(),
        "bar": orders.filter(lines__menu_item__department="bar").distinct().count(),
        "service_requests": _for_user_property(
            ServiceRequest.objects.filter(created_at__date=report_date),
            request.user,
        ).count(),
        "awaiting_payment": orders.filter(payment_status="review").count(),
        **_base(request),
    }
    return render(request, "portal/reports.html", context)


@login_required
@user_passes_test(_manager_only, login_url="dashboard")
def settings_page(request):
    settings_record = _property_for_user(request.user)
    form = PortalSettingsForm(request.POST or None, instance=settings_record)
    if request.method == "POST" and form.is_valid():
        form.save()
        messages.success(request, "Property settings saved.")
        return redirect("settings")
    return render(
        request,
        "portal/settings.html",
        {"form": form, **_base(request)},
    )


@login_required
@user_passes_test(_can_manage_configuration, login_url="dashboard")
def staff_shifts(request):
    settings_record = _property_for_user(request.user)
    if settings_record is None:
        return HttpResponse("This account is not assigned to a property.", status=403)
    selected_shift = (
        request.POST.get("shift")
        if request.method == "POST"
        else request.GET.get("shift")
    ) or (settings_record.active_shift if settings_record else "morning")
    valid_shifts = dict(SHIFT_CHOICES)
    if selected_shift not in valid_shifts:
        selected_shift = settings_record.active_shift if settings_record else "morning"

    if request.method == "POST":
        selected_staff = {}
        for department, _ in ROUTING_DEPARTMENTS:
            staff_id = request.POST.get(f"staff_{department}", "").strip()
            if not staff_id:
                selected_staff[department] = None
                continue
            profile = StaffProfile.objects.filter(
                pk=staff_id,
                property=_property_for_user(request.user),
                active=True,
                user__is_active=True,
            ).first()
            if profile is None:
                messages.error(
                    request,
                    "Assignments can only use active, registered staff accounts.",
                )
                break
            selected_staff[department] = profile
        else:
            with transaction.atomic():
                for department, _ in ROUTING_DEPARTMENTS:
                    ShiftAssignment.objects.update_or_create(
                        property=settings_record,
                        shift=selected_shift,
                        department=department,
                        defaults={"staff": selected_staff[department]},
                    )
                settings_record.active_shift = selected_shift
                settings_record.save(update_fields=["active_shift", "updated_at"])
            messages.success(request, "Shift assignments saved.")
            return redirect(f"{reverse('staff_shifts')}?shift={selected_shift}")

    all_staff = list(
        StaffProfile.objects.filter(
            property=_property_for_user(request.user),
            active=True,
            user__is_active=True,
        )
        .select_related("user")
        .order_by("user__first_name", "user__last_name", "user__username")
    )
    assigned_by_department = {
        assignment.department: assignment.staff
        for assignment in ShiftAssignment.objects.filter(
            property=_property_for_user(request.user), shift=selected_shift
        ).select_related("staff__user")
    }
    active_shift = settings_record.active_shift if settings_record else "morning"
    active_assignments = {
        assignment.department: assignment.staff
        for assignment in ShiftAssignment.objects.filter(
            property=_property_for_user(request.user), shift=active_shift
        ).select_related("staff__user")
    }
    assignment_cards = [
        {
            "code": code,
            "label": label,
            "staff": assigned_by_department.get(code),
        }
        for code, label in ROUTING_DEPARTMENTS
    ]
    today = timezone.localdate()
    todays_orders = _for_user_property(
        Order.objects.filter(created_at__date=today).prefetch_related(
            "lines__menu_item", "notifications__staff__user"
        ),
        request.user,
    )
    live_items = []
    for order in todays_orders.exclude(status__in=["completed", "cancelled"]):
        departments = {
            line.menu_item.department
            for line in order.lines.all()
            if line.menu_item_id is not None
        }
        for department in departments:
            attempt = order.notifications.filter(department=department).first()
            assignment = active_assignments.get(department)
            live_items.append(
                {
                    "kind": "order",
                    "reference": order.order_number,
                    "summary": ", ".join(
                        f"{line.item_name} × {line.quantity}"
                        for line in order.lines.all()
                        if line.menu_item_id is not None
                        and line.menu_item.department == department
                    ),
                    "room": order.room_identifier or "—",
                    "department": dict(ROUTING_DEPARTMENTS).get(department, department),
                    "staff": attempt.staff if attempt else assignment,
                    "status": order.get_status_display(),
                    "notification": (
                        attempt.get_status_display() if attempt else "No notification record"
                    ),
                    "order": order,
                    "next_status": {
                        "new": ("accepted", "Mark accepted"),
                        "accepted": ("preparing", "Mark preparing"),
                        "preparing": ("ready", "Mark ready"),
                        "ready": ("completed", "Mark complete"),
                    }.get(order.status),
                }
            )
    service_requests = _for_user_property(
        ServiceRequest.objects.exclude(
            status__in=["completed", "cancelled"]
        ).select_related("service", "device").prefetch_related(
            "notifications__staff__user"
        ),
        request.user,
    )
    for service_request in service_requests[:30]:
        attempt = service_request.notifications.first()
        service_department = (
            service_request.service.department if service_request.service else "services"
        )
        department = (
            service_department
            if service_department in {"kitchen", "bar"}
            else "services"
        )
        assignment = active_assignments.get(department)
        live_items.append(
            {
                "kind": "service",
                "reference": f"SR-{service_request.pk:03d}",
                "summary": service_request.service.name
                if service_request.service
                else service_request.details or "Guest request",
                "room": service_request.room_identifier or "—",
                "department": dict(ROUTING_DEPARTMENTS)[department],
                "staff": attempt.staff if attempt else assignment,
                "status": service_request.get_status_display(),
                "notification": (
                    attempt.get_status_display() if attempt else "No notification record"
                ),
                "service_request": service_request,
                "next_status": {
                    "new": ("accepted", "Mark accepted"),
                    "accepted": ("in_progress", "Mark in progress"),
                    "in_progress": ("completed", "Mark complete"),
                }.get(service_request.status),
            }
        )

    recent_activity = _for_user_property(
        WhatsAppAttempt.objects.select_related(
            "staff__user", "order", "service_request"
        ),
        request.user,
    )[:8]
    active_staff_ids = {
        assignment.staff_id
        for assignment in ShiftAssignment.objects.filter(
            property=_property_for_user(request.user), shift=selected_shift
        ).select_related("staff__user")
        if assignment.staff_id
        and assignment.staff.active
        and assignment.staff.user.is_active
    }
    return render(
        request,
        "portal/staff_shifts.html",
        {
            "shift_choices": SHIFT_CHOICES,
            "selected_shift": selected_shift,
            "active_shift_label": valid_shifts[active_shift],
            "assignment_cards": assignment_cards,
            "staff_members": all_staff,
            "staff_on_duty": len(active_staff_ids),
            "orders_today": todays_orders.count(),
            "awaiting_acceptance": _for_user_property(
                Order.objects.filter(status="new"), request.user
            ).count()
            + _for_user_property(
                ServiceRequest.objects.filter(status="new"), request.user
            ).count(),
            "whatsapp_enabled": (
                settings_record.whatsapp_enabled if settings_record else True
            ),
            "live_items": live_items[:50],
            "recent_activity": recent_activity,
            **_base(request),
        },
    )


def health(request):
    return HttpResponse("ok", content_type="text/plain")
