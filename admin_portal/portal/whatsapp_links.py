import re
from urllib.parse import quote

from .models import ROUTING_DEPARTMENTS


def whatsapp_number(phone_number):
    digits = re.sub(r"\D", "", phone_number or "")
    if digits.startswith("0"):
        digits = f"234{digits[1:]}"
    elif len(digits) == 10 and digits[0] in "789":
        digits = f"234{digits}"
    return digits if 8 <= len(digits) <= 15 else ""


def order_notification_text(order, department):
    department_label = dict(ROUTING_DEPARTMENTS).get(department, department.title())
    department_lines = [
        line
        for line in order.lines.all()
        if line.menu_item_id and line.menu_item.department == department
    ]
    items = ", ".join(
        f"{line.item_name} x{line.quantity}" for line in department_lines
    )
    lines = [
        f"HAIDWARE {department_label} payment confirmation",
        f"Order: {order.order_number}",
        f"Room/Table: {order.room_identifier or 'Not assigned'}",
        f"Sender name: {order.sender_name}",
        f"{department_label} items: {items}",
        f"Total: NGN {order.total:,.0f}",
        "Please check and confirm the payment with reception.",
    ]
    return "\n".join(lines)


def whatsapp_link(phone_number, message):
    number = whatsapp_number(phone_number)
    if not number:
        return ""
    return f"https://wa.me/{number}?text={quote(message)}"
