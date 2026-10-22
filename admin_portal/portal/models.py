import secrets
import uuid

from django.conf import settings
from django.core.validators import MinValueValidator, StepValueValidator
from django.db import models
from decimal import Decimal


def generate_device_id():
    while True:
        device_id = str(secrets.randbelow(9_000_000_000) + 1_000_000_000)
        if not Device.objects.filter(device_id=device_id).exists():
            return device_id


class Room(models.Model):
    ROOM_TYPES = [
        ("room", "Room"),
        ("table", "Table"),
        ("suite", "Suite"),
        ("area", "Area"),
    ]

    identifier = models.CharField(max_length=80, unique=True)
    room_type = models.CharField(max_length=12, choices=ROOM_TYPES, default="room")
    floor = models.CharField(max_length=80, blank=True)
    notes = models.TextField(blank=True)
    active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["identifier"]

    def __str__(self):
        return self.identifier

    @property
    def active_qr_device(self):
        if not self.active:
            return None
        return next(
            (
                device
                for device in self.devices.all()
                if device.active and device.is_qr_device
            ),
            None,
        )

    def ensure_ordering_device(self):
        if not self.active:
            return None
        existing_device = self.active_qr_device
        if existing_device is not None:
            return existing_device
        return Device.objects.create(
            name=f"QR · {self.identifier}",
            device_id=generate_device_id(),
            room=self,
            is_qr_device=True,
        )


class Device(models.Model):
    name = models.CharField(max_length=100)
    device_id = models.CharField(max_length=12, unique=True)
    room = models.ForeignKey(
        Room, null=True, blank=True, on_delete=models.SET_NULL, related_name="devices"
    )
    is_qr_device = models.BooleanField(default=False)
    active = models.BooleanField(default=True)
    last_seen = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return f"{self.name} ({self.device_id})"


class MenuItem(models.Model):
    DEPARTMENTS = [("kitchen", "Kitchen"), ("bar", "Bar")]

    name = models.CharField(max_length=120)
    department = models.CharField(max_length=12, choices=DEPARTMENTS)
    category = models.CharField(max_length=80)
    description = models.TextField(blank=True)
    price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        validators=[
            MinValueValidator(Decimal("0.00")),
            StepValueValidator(Decimal("1.00")),
        ],
    )
    preparation_minutes = models.PositiveSmallIntegerField(default=25)
    available = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["department", "category", "name"]

    image_url = models.URLField(blank=True)

    def __str__(self):
        return self.name


class ServiceOption(models.Model):
    DEPARTMENTS = [
        ("housekeeping", "Housekeeping"),
        ("laundry", "Laundry"),
        ("maintenance", "Maintenance"),
        ("reception", "Reception"),
        ("amenities", "Amenities"),
        ("kitchen", "Kitchen"),
        ("bar", "Bar"),
        ("other", "Other"),
    ]

    name = models.CharField(max_length=120)
    department = models.CharField(max_length=20, choices=DEPARTMENTS)
    description = models.TextField(blank=True)
    active = models.BooleanField(default=True)

    class Meta:
        ordering = ["department", "name"]

    def __str__(self):
        return self.name


class StaffProfile(models.Model):
    ROLES = [
        ("manager", "Manager / Director"),
        ("admin", "Administrator"),
        ("reception", "Reception / Staff"),
        ("handler", "Order Handler"),
    ]

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="staff_profile"
    )
    role = models.CharField(max_length=16, choices=ROLES, default="reception")
    departments = models.CharField(max_length=160, blank=True)
    phone_number = models.CharField(max_length=24, blank=True, default="")
    active = models.BooleanField(default=True)

    def __str__(self):
        return f"{self.user.get_username()} ({self.get_role_display()})"


SHIFT_CHOICES = [
    ("morning", "Morning · 7am–3pm"),
    ("evening", "Evening · 3pm–11pm"),
    ("night", "Night · 11pm–7am"),
]
ROUTING_DEPARTMENTS = [
    ("kitchen", "Kitchen"),
    ("bar", "Bar"),
    ("services", "Services"),
]


class ShiftAssignment(models.Model):
    shift = models.CharField(max_length=12, choices=SHIFT_CHOICES)
    department = models.CharField(max_length=12, choices=ROUTING_DEPARTMENTS)
    staff = models.ForeignKey(
        StaffProfile,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="shift_assignments",
    )
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["shift", "department"], name="unique_shift_department"
            )
        ]

    def __str__(self):
        return f"{self.get_shift_display()} · {self.get_department_display()}"


class Order(models.Model):
    ORDER_STATUSES = [
        ("new", "New"),
        ("accepted", "Accepted"),
        ("preparing", "Preparing"),
        ("ready", "Ready / On the Way"),
        ("completed", "Completed"),
        ("cancelled", "Cancelled"),
    ]
    PAYMENT_STATUSES = [
        ("awaiting", "Awaiting Payment"),
        ("review", "Awaiting Verification"),
        ("confirmed", "Confirmed"),
        ("rejected", "Rejected"),
    ]

    order_number = models.CharField(max_length=24, unique=True, editable=False)
    device = models.ForeignKey(
        Device, on_delete=models.PROTECT, related_name="orders"
    )
    room_identifier = models.CharField(max_length=80, blank=True)
    sender_name = models.CharField(max_length=120, blank=True)
    status = models.CharField(max_length=12, choices=ORDER_STATUSES, default="new")
    payment_status = models.CharField(
        max_length=12, choices=PAYMENT_STATUSES, default="awaiting"
    )
    payment_confirmed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="confirmed_orders",
    )
    payment_confirmed_at = models.DateTimeField(null=True, blank=True)
    service_charge = models.DecimalField(
        max_digits=10, decimal_places=2, default=Decimal("0.00")
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def save(self, *args, **kwargs):
        if not self.order_number:
            self.order_number = f"HDW-{uuid.uuid4().hex[:10].upper()}"
        if self.device.room_id and not self.room_identifier:
            self.room_identifier = self.device.room.identifier
        super().save(*args, **kwargs)

    @property
    def subtotal(self):
        return sum((line.total for line in self.lines.all()), start=0)

    @property
    def total(self):
        return self.subtotal + self.service_charge

    @property
    def estimated_minutes(self):
        return max((line.preparation_minutes for line in self.lines.all()), default=0)

    def __str__(self):
        return self.order_number


class OrderLine(models.Model):
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name="lines")
    menu_item = models.ForeignKey(
        MenuItem, null=True, blank=True, on_delete=models.SET_NULL
    )
    item_name = models.CharField(max_length=120)
    unit_price = models.DecimalField(max_digits=10, decimal_places=2)
    quantity = models.PositiveSmallIntegerField()
    preparation_minutes = models.PositiveSmallIntegerField(default=25)

    @property
    def total(self):
        return self.unit_price * self.quantity


class ServiceRequest(models.Model):
    STATUSES = [
        ("new", "New"),
        ("accepted", "Accepted"),
        ("in_progress", "In Progress"),
        ("completed", "Completed"),
        ("cancelled", "Cancelled"),
    ]

    request_number = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    device = models.ForeignKey(
        Device, on_delete=models.PROTECT, related_name="service_requests"
    )
    room_identifier = models.CharField(max_length=80, blank=True)
    service = models.ForeignKey(
        ServiceOption, null=True, blank=True, on_delete=models.SET_NULL
    )
    details = models.TextField(blank=True)
    status = models.CharField(max_length=16, choices=STATUSES, default="new")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]


class WhatsAppAttempt(models.Model):
    DELIVERY_STATUSES = [
        ("demo", "Demo only · API not connected"),
        ("failed", "Failed · Follow up required"),
        ("disabled", "WhatsApp routing disabled"),
    ]

    order = models.ForeignKey(
        Order, null=True, blank=True, on_delete=models.CASCADE, related_name="notifications"
    )
    service_request = models.ForeignKey(
        ServiceRequest,
        null=True,
        blank=True,
        on_delete=models.CASCADE,
        related_name="notifications",
    )
    department = models.CharField(max_length=12, choices=ROUTING_DEPARTMENTS)
    staff = models.ForeignKey(
        StaffProfile,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="whatsapp_attempts",
    )
    recipient_number = models.CharField(max_length=24, blank=True)
    status = models.CharField(max_length=12, choices=DELIVERY_STATUSES)
    detail = models.CharField(max_length=240, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]


class PortalSettings(models.Model):
    SHIFT_CHOICES = SHIFT_CHOICES

    property_name = models.CharField(max_length=120, default="HAIDWARE Hospitality")
    currency = models.CharField(max_length=8, default="NGN")
    bank_name = models.CharField(max_length=120, blank=True)
    account_name = models.CharField(max_length=120, blank=True)
    account_number = models.CharField(max_length=32, blank=True)
    active_shift = models.CharField(
        max_length=12, choices=SHIFT_CHOICES, default="morning"
    )
    whatsapp_enabled = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.property_name
