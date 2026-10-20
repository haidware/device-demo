from django.contrib import admin

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
    WhatsAppAttempt,
)


class OrderLineInline(admin.TabularInline):
    model = OrderLine
    extra = 0
    readonly_fields = ["item_name", "unit_price", "quantity", "preparation_minutes"]


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = [
        "order_number",
        "device",
        "status",
        "payment_status",
        "sender_name",
        "created_at",
    ]
    list_filter = ["status", "payment_status", "created_at"]
    search_fields = ["order_number", "sender_name", "room_identifier"]
    inlines = [OrderLineInline]


admin.site.register(
    [
        Device,
        MenuItem,
        PortalSettings,
        Room,
        ServiceOption,
        ServiceRequest,
        StaffProfile,
        ShiftAssignment,
        WhatsAppAttempt,
    ]
)
