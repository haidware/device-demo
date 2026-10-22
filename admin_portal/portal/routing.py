from .models import (
    OrderLine,
    ROUTING_DEPARTMENTS,
    ShiftAssignment,
    WhatsAppAttempt,
)


def _record_routing_attempts(*, order=None, service_request=None):
    if order is not None:
        departments = set(
            OrderLine.objects.filter(order=order, menu_item__isnull=False).values_list(
                "menu_item__department", flat=True
            )
        )
    else:
        service_department = (
            service_request.service.department if service_request.service else "services"
        )
        departments = {
            service_department if service_department in {"kitchen", "bar"} else "services"
        }

    property_record = (
        order.property if order is not None else service_request.property
    )
    shift = property_record.active_shift
    enabled = property_record.whatsapp_enabled
    department_labels = dict(ROUTING_DEPARTMENTS)
    for department in sorted(departments):
        assignment = (
            ShiftAssignment.objects.select_related("staff__user")
            .filter(
                property=property_record,
                shift=shift,
                department=department,
            )
            .first()
        )
        staff = assignment.staff if assignment else None
        if not enabled:
            status = "disabled"
            detail = "WhatsApp routing is disabled in portal settings."
        elif (
            staff is None
            or not staff.active
            or not staff.user.is_active
            or not staff.phone_number.strip()
        ):
            status = "failed"
            detail = f"No active staff contact assigned for {department_labels[department]}."
        else:
            status = "demo"
            detail = (
                "No WhatsApp message was sent automatically. An authorized "
                "operator can open the dashboard link and tap Send."
            )

        WhatsAppAttempt.objects.create(
            property=property_record,
            order=order,
            service_request=service_request,
            department=department,
            staff=staff,
            recipient_number=staff.phone_number if staff else "",
            status=status,
            detail=detail,
        )
