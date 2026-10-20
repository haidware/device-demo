import json
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.urls import reverse

from .models import (
    Device,
    MenuItem,
    Order,
    OrderLine,
    PortalSettings,
    Room,
    ShiftAssignment,
    StaffProfile,
    WhatsAppAttempt,
)

User = get_user_model()


class PortalFlowTests(TestCase):
    def setUp(self):
        self.admin = User.objects.create_superuser(
            username="admin", email="admin@example.test", password="SecurePass123!test"
        )
        self.room = Room.objects.create(identifier="101")
        self.device = Device.objects.create(
            name="Room 101 tablet", device_id="123456", room=self.room
        )
        self.item = MenuItem.objects.create(
            name="Jollof Rice",
            department="kitchen",
            category="Main",
            price=Decimal("5000.00"),
            preparation_minutes=25,
        )

    def test_admin_entry_and_qr_order_use_public_routes(self):
        self.assertEqual(reverse("dashboard"), "/admin/dashboard/")
        self.assertEqual(reverse("guest_order"), "/guest-order/")

        response = self.client.get("/admin/")

        self.assertRedirects(response, reverse("dashboard"), fetch_redirect_response=False)

    def test_login_required_for_portal_and_staff_management(self):
        response = self.client.get(reverse("dashboard"))
        self.assertRedirects(response, f"{reverse('login')}?next={reverse('dashboard')}")
        self.client.force_login(self.admin)
        response = self.client.get(reverse("staff"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Add Staff")

    def test_staff_page_displays_registered_members_as_profile_cards(self):
        staff_user = User.objects.create_user(
            username="amara",
            password="a-valid-test-password",
            first_name="Amara",
            last_name="Okafor",
        )
        StaffProfile.objects.create(
            user=staff_user,
            role="reception",
            departments="Kitchen, Services",
            phone_number="+2348012345678",
        )
        self.client.force_login(self.admin)

        response = self.client.get(reverse("staff"))

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, 'aria-label="Registered staff"')
        self.assertContains(response, "Amara Okafor")
        self.assertContains(response, "Kitchen, Services")
        self.assertContains(response, "+2348012345678")
        self.assertContains(response, "Deactivate account")
        self.assertContains(response, "<strong>1</strong>", html=True)

    def test_admin_portal_pages_render(self):
        self.client.force_login(self.admin)
        for name, args in [
            ("dashboard", []),
            ("orders", []),
            ("service_requests", []),
            ("payments", []),
            ("handler", []),
            ("menu_list", ["kitchen"]),
            ("menu_list", ["bar"]),
            ("services", []),
            ("rooms", []),
            ("devices", []),
            ("staff", []),
            ("staff_shifts", []),
            ("reports", []),
            ("settings", []),
            ("room_add", []),
            ("device_add", []),
            ("menu_add", []),
            ("staff_add", []),
        ]:
            with self.subTest(page=name, args=args):
                response = self.client.get(reverse(name, args=args))
                self.assertEqual(response.status_code, 200)

    def test_guest_order_page_is_public_and_receives_qr_device_id(self):
        response = self.client.get(
            reverse("guest_order"),
            {"device_id": self.device.device_id},
        )
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "guest-order.js")
        self.assertContains(response, self.device.device_id)

    def test_device_session_returns_registered_device(self):
        PortalSettings.objects.create(
            property_name="Demo Hotel",
            bank_name="GTBank",
            account_name="Demo Hotel Ltd",
            account_number="0123456789",
        )
        response = self.client.post(
            reverse("api_device_session"),
            data=json.dumps({"device_id": "123456"}),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["room"], "101")
        self.assertEqual(
            response.json()["payment_details"]["account_number"], "0123456789"
        )
        self.assertIsNotNone(Device.objects.get(pk=self.device.pk).last_seen)

    def test_device_cannot_access_portal_when_inactive(self):
        self.device.active = False
        self.device.save(update_fields=["active"])
        response = self.client.post(
            reverse("api_device_session"),
            data=json.dumps({"device_id": "123456"}),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 403)

    def test_room_device_cannot_access_ordering_when_room_is_inactive(self):
        self.room.active = False
        self.room.save(update_fields=["active"])
        response = self.client.post(
            reverse("api_device_session"),
            data=json.dumps({"device_id": "123456"}),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 403)

    def test_room_creation_generates_internal_device_id_automatically(self):
        self.client.force_login(self.admin)
        response = self.client.post(
            reverse("room_add"),
            {
                "identifier": "205",
                "room_type": "room",
                "floor": "Second floor",
                "notes": "",
                "active": "on",
            },
        )
        self.assertRedirects(response, reverse("rooms"))
        room = Room.objects.get(identifier="205")
        device = room.active_qr_device
        self.assertIsNotNone(device)
        self.assertRegex(device.device_id, r"^\d{10}$")
        self.assertEqual(device.room, room)

    def test_device_registration_generates_id_and_assigns_selected_room(self):
        self.client.force_login(self.admin)
        response = self.client.post(
            reverse("device_add"),
            {
                "name": "Room 101 ordering tablet",
                "room": str(self.room.pk),
                "active": "on",
            },
        )
        self.assertRedirects(response, reverse("devices"))
        device = Device.objects.get(name="Room 101 ordering tablet")
        self.assertRegex(device.device_id, r"^\d{10}$")
        self.assertEqual(device.room, self.room)

    def test_menu_api_only_exposes_admin_available_items(self):
        unavailable = MenuItem.objects.create(
            name="Hidden Soup",
            department="kitchen",
            category="Soup",
            price=Decimal("1200.00"),
            available=False,
        )
        response = self.client.get(
            reverse("api_device_menu"),
            HTTP_X_DEVICE_ID="123456",
        )
        self.assertEqual(response.status_code, 200)
        item_ids = {entry["id"] for entry in response.json()["items"]}
        self.assertIn(self.item.pk, item_ids)
        self.assertNotIn(unavailable.pk, item_ids)
        self.assertEqual(
            response.json()["items"][0]["department"],
            "kitchen",
        )

    def test_paid_order_is_created_for_staff_payment_review(self):
        response = self.client.post(
            reverse("api_create_order"),
            data=json.dumps(
                {
                    "device_id": "123456",
                    "sender_name": "Jane Customer",
                    "expected_total": 11000,
                    "items": [{"item_id": self.item.pk, "quantity": 2}],
                }
            ),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 201)
        payload = response.json()
        self.assertEqual(payload["total"], "11000.00")
        self.assertEqual(payload["payment_status"], "review")
        order = Order.objects.get(order_number=payload["order_number"])
        self.assertEqual(order.sender_name, "Jane Customer")
        self.assertEqual(order.lines.get().quantity, 2)

    def test_client_cannot_override_menu_price(self):
        response = self.client.post(
            reverse("api_create_order"),
            data=json.dumps(
                {
                    "device_id": "123456",
                    "sender_name": "Jane Customer",
                    "expected_total": 5500,
                    "items": [
                        {"item_id": self.item.pk, "quantity": 1, "price": "1.00"}
                    ],
                }
            ),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 201)
        self.assertEqual(OrderLine.objects.get().unit_price, Decimal("5000.00"))

    def test_rejects_order_when_paid_total_no_longer_matches_menu(self):
        response = self.client.post(
            reverse("api_create_order"),
            data=json.dumps(
                {
                    "device_id": "123456",
                    "sender_name": "Jane Customer",
                    "expected_total": 1,
                    "items": [{"item_id": self.item.pk, "quantity": 1}],
                }
            ),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 409)
        self.assertEqual(Order.objects.count(), 0)

    def test_menu_price_must_be_a_whole_naira_value(self):
        self.client.force_login(self.admin)
        form_response = self.client.post(
            reverse("menu_add"),
            {
                "name": "Tea",
                "department": "bar",
                "category": "Drinks",
                "description": "",
                "price": "1500.50",
                "preparation_minutes": 5,
                "available": "on",
            },
        )
        self.assertEqual(form_response.status_code, 200)
        self.assertFalse(MenuItem.objects.filter(name="Tea").exists())

    def test_reception_can_confirm_payment(self):
        self.client.force_login(self.admin)
        order = Order.objects.create(
            device=self.device, sender_name="Jane", payment_status="review"
        )
        OrderLine.objects.create(
            order=order,
            menu_item=self.item,
            item_name=self.item.name,
            unit_price=self.item.price,
            quantity=1,
            preparation_minutes=25,
        )
        response = self.client.post(
            reverse("update_order", args=[order.pk]),
            {"action": "confirm_payment"},
        )
        self.assertRedirects(response, reverse("order_detail", args=[order.pk]))
        order.refresh_from_db()
        self.assertEqual(order.payment_status, "confirmed")
        self.assertEqual(order.payment_confirmed_by, self.admin)

    def test_staff_registration_saves_name_role_and_contact(self):
        self.client.force_login(self.admin)
        response = self.client.post(
            reverse("staff_add"),
            {
                "username": "kitchen.staff",
                "first_name": "Kitchen",
                "last_name": "Staff",
                "password": "Strong-Unique-Passphrase-9281",
                "role": "handler",
                "departments": "Kitchen",
                "phone_number": "+234 801 234 5678",
            },
        )
        self.assertRedirects(response, reverse("staff"))
        profile = StaffProfile.objects.get(user__username="kitchen.staff")
        self.assertEqual(profile.phone_number, "+234 801 234 5678")
        self.assertEqual(profile.role, "handler")

    def test_staff_registration_rejects_invalid_contact_number(self):
        self.client.force_login(self.admin)
        response = self.client.post(
            reverse("staff_add"),
            {
                "username": "staff.invalid",
                "password": "Strong-Unique-Passphrase-9281",
                "role": "handler",
                "phone_number": "not-a-phone",
            },
        )
        self.assertEqual(response.status_code, 200)
        self.assertFalse(User.objects.filter(username="staff.invalid").exists())

    def test_shift_assignment_routes_demo_notification_without_sending(self):
        staff_user = User.objects.create_user(
            username="kitchen.staff",
            password="Strong-Unique-Passphrase-9281",
            first_name="Kitchen",
            last_name="Staff",
        )
        staff = StaffProfile.objects.create(
            user=staff_user, role="handler", phone_number="+234 801 234 5678"
        )
        self.client.force_login(self.admin)
        response = self.client.post(
            reverse("staff_shifts"),
            {
                "shift": "evening",
                "staff_kitchen": str(staff.pk),
                "staff_bar": "",
                "staff_services": "",
            },
        )
        self.assertRedirects(
            response, f"{reverse('staff_shifts')}?shift=evening"
        )
        self.assertEqual(
            ShiftAssignment.objects.get(
                shift="evening", department="kitchen"
            ).staff,
            staff,
        )
        self.assertEqual(PortalSettings.objects.get().active_shift, "evening")

        order_response = self.client.post(
            reverse("api_create_order"),
            data=json.dumps(
                {
                    "device_id": "123456",
                    "sender_name": "Jane Customer",
                    "expected_total": 5500,
                    "items": [{"item_id": self.item.pk, "quantity": 1}],
                }
            ),
            content_type="application/json",
        )
        self.assertEqual(order_response.status_code, 201)
        attempt = WhatsAppAttempt.objects.get(order__order_number=order_response.json()["order_number"])
        self.assertEqual(attempt.status, "demo")
        self.assertEqual(attempt.staff, staff)
        self.assertEqual(attempt.recipient_number, staff.phone_number)
        self.assertIn("no WhatsApp message was sent", attempt.detail)

    def test_unassigned_department_logs_failed_notification(self):
        response = self.client.post(
            reverse("api_create_order"),
            data=json.dumps(
                {
                    "device_id": "123456",
                    "sender_name": "Jane Customer",
                    "expected_total": 5500,
                    "items": [{"item_id": self.item.pk, "quantity": 1}],
                }
            ),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 201)
        attempt = WhatsAppAttempt.objects.get()
        self.assertEqual(attempt.status, "failed")
        self.assertIn("No active staff contact assigned", attempt.detail)

    def test_handler_staff_is_limited_to_notification_only_access(self):
        order = Order.objects.create(device=self.device)
        staff_user = User.objects.create_user(
            username="handler", password="Strong-Unique-Passphrase-9281"
        )
        StaffProfile.objects.create(user=staff_user, role="handler")
        self.client.force_login(staff_user)

        dashboard_response = self.client.get(reverse("dashboard"))
        self.assertContains(dashboard_response, "Notifications only")
        self.assertNotContains(dashboard_response, order.order_number)
        self.assertNotContains(dashboard_response, "Payments")
        orders_response = self.client.get(reverse("orders"))
        self.assertEqual(orders_response.status_code, 302)
        self.assertEqual(
            orders_response["Location"],
            f"{reverse('dashboard')}?next={reverse('orders')}",
        )
        update_response = self.client.post(
            reverse("update_order", args=[order.pk]),
            {"action": "update_status", "status": "completed"},
        )
        self.assertEqual(update_response.status_code, 302)
        self.assertEqual(
            update_response["Location"],
            f"{reverse('dashboard')}?next={reverse('update_order', args=[order.pk])}",
        )
        order.refresh_from_db()
        self.assertEqual(order.status, "new")

    def test_room_qr_is_generated_for_location_and_opens_browser_ordering(self):
        self.device.active = False
        self.device.save(update_fields=["active"])
        self.client.force_login(self.admin)
        qr_page = self.client.get(reverse("room_qr", args=[self.room.pk]))
        self.assertContains(qr_page, "Generate QR Code")

        response = self.client.post(reverse("room_qr", args=[self.room.pk]))
        self.assertRedirects(response, reverse("room_qr", args=[self.room.pk]))
        device = Device.objects.get(room=self.room, active=True)
        self.assertNotEqual(device.device_id, "123456")

        qr_page = self.client.get(reverse("room_qr", args=[self.room.pk]))
        self.assertContains(qr_page, "confirmation flow as the device, in a browser")
        self.assertContains(
            qr_page,
            f"http://testserver/guest-order/?device_id={device.device_id}",
        )
        qr_image = self.client.get(reverse("room_qr_image", args=[self.room.pk]))
        self.assertEqual(qr_image.status_code, 200)
        self.assertEqual(qr_image["Content-Type"], "image/svg+xml")
        self.assertIn(b"<svg", qr_image.content)

        session = self.client.post(
            reverse("api_device_session"),
            data=json.dumps({"device_id": device.device_id}),
            content_type="application/json",
        )
        self.assertEqual(session.status_code, 200)
        self.assertEqual(session.json()["room"], "101")

    @override_settings(GUEST_ORDER_BASE_URL="http://192.168.0.127:8000/guest-order/")
    def test_qr_uses_configured_guest_order_base_url(self):
        self.client.force_login(self.admin)
        response = self.client.get(reverse("room_qr", args=[self.room.pk]))
        self.assertContains(
            response,
            f"http://192.168.0.127:8000/guest-order/?device_id={self.device.device_id}",
        )

    def test_regenerating_room_qr_reuses_active_device(self):
        self.client.force_login(self.admin)
        for _ in range(2):
            response = self.client.post(reverse("room_qr", args=[self.room.pk]))
            self.assertRedirects(response, reverse("room_qr", args=[self.room.pk]))
        self.assertEqual(Device.objects.filter(room=self.room, active=True).count(), 1)

    def test_only_admin_can_generate_room_qr(self):
        reception = User.objects.create_user(username="reception", password="test")
        StaffProfile.objects.create(user=reception, role="reception")
        self.client.force_login(reception)
        response = self.client.post(reverse("room_qr", args=[self.room.pk]))
        self.assertEqual(response.status_code, 403)
        self.assertFalse(
            Device.objects.filter(room=self.room, name__startswith="QR").exists()
        )

    def test_unallowed_browser_origin_receives_no_cors_grant(self):
        response = self.client.options(
            reverse("api_device_menu"),
            HTTP_ORIGIN="https://untrusted.example",
        )
        self.assertNotIn("Access-Control-Allow-Origin", response.headers)
