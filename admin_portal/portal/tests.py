import json
from decimal import Decimal
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.urls import reverse

from .models import (
    Device,
    MenuItem,
    Order,
    OrderLine,
    PortalSettings,
    Room,
    ServiceOption,
    ShiftAssignment,
    StaffProfile,
    WhatsAppAttempt,
)
from .whatsapp_links import order_notification_text, whatsapp_link, whatsapp_number

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

    def test_manager_signup_creates_manager_role_and_session(self):
        response = self.client.post(
            reverse("manager_signup"),
            {
                "username": "property.manager",
                "first_name": "Property",
                "last_name": "Manager",
                "email": "manager@example.test",
                "password1": "Unique-Manager-Passphrase-2841",
                "password2": "Unique-Manager-Passphrase-2841",
            },
        )

        self.assertRedirects(response, reverse("dashboard"))
        manager = User.objects.get(username="property.manager")
        self.assertEqual(manager.staff_profile.role, "manager")
        self.assertIn("_auth_user_id", self.client.session)

    def test_manager_can_create_admin_account_and_set_bank_details(self):
        manager = User.objects.create_user(
            username="manager",
            password="Strong-Manager-Passphrase-2841",
        )
        StaffProfile.objects.create(user=manager, role="manager")
        self.client.force_login(manager)

        staff_response = self.client.post(
            reverse("staff_add"),
            {
                "username": "testing.admin",
                "password": "Strong-Admin-Passphrase-9281",
                "role": "admin",
                "departments": "Kitchen, Bar",
                "phone_number": "+234 801 234 5678",
            },
        )
        self.assertRedirects(staff_response, reverse("staff"))
        self.assertEqual(
            User.objects.get(username="testing.admin").staff_profile.role,
            "admin",
        )

        settings_response = self.client.post(
            reverse("settings"),
            {
                "property_name": "Demo Hotel",
                "currency": "NGN",
                "bank_name": "Demo Bank",
                "account_name": "Demo Hotel Ltd",
                "account_number": "0123456789",
                "active_shift": "morning",
                "whatsapp_enabled": "on",
            },
        )
        self.assertRedirects(settings_response, reverse("settings"))
        self.assertEqual(PortalSettings.objects.get().account_number, "0123456789")

    def test_admin_can_edit_service_description_and_department(self):
        service = ServiceOption.objects.create(
            name="Fresh Towels",
            department="housekeeping",
            description="Delivered to your room.",
        )
        self.client.force_login(self.admin)

        response = self.client.post(
            reverse("service_edit", args=[service.pk]),
            {
                "name": "Extra Towels",
                "department": "housekeeping",
                "description": "Fresh towels delivered to your room.",
                "active": "on",
            },
        )

        self.assertRedirects(response, reverse("services"))
        service.refresh_from_db()
        self.assertEqual(service.name, "Extra Towels")
        self.assertEqual(service.description, "Fresh towels delivered to your room.")

    def test_admin_cannot_create_admin_or_edit_payout_details(self):
        site_admin = User.objects.create_user(
            username="site.admin",
            password="Strong-Admin-Passphrase-9281",
        )
        StaffProfile.objects.create(user=site_admin, role="admin")
        self.client.force_login(site_admin)
        create_response = self.client.post(
            reverse("staff_add"),
            {
                "username": "unauthorized.admin",
                "password": "Strong-Admin-Passphrase-9281",
                "role": "admin",
                "phone_number": "+234 801 234 5678",
            },
        )
        self.assertEqual(create_response.status_code, 200)
        self.assertFalse(User.objects.filter(username="unauthorized.admin").exists())
        settings_response = self.client.get(reverse("settings"))
        self.assertEqual(settings_response.status_code, 302)
        self.assertFalse(PortalSettings.objects.exists())

    def test_manager_can_upload_photo_to_menu_item_edit(self):
        manager = User.objects.create_user(
            username="photo.manager",
            password="Strong-Manager-Passphrase-2841",
        )
        StaffProfile.objects.create(user=manager, role="manager")
        self.client.force_login(manager)
        photo = SimpleUploadedFile(
            "updated.png",
            b"\x89PNG\r\n\x1a\nphoto-bytes",
            content_type="image/png",
        )

        with patch(
            "portal.views.store_menu_image",
            return_value="https://storage.test/menu/updated.png",
        ) as store_image:
            response = self.client.post(
                reverse("menu_edit", args=[self.item.pk]),
                {
                    "name": self.item.name,
                    "department": self.item.department,
                    "category": self.item.category,
                    "description": self.item.description,
                    "price": str(self.item.price),
                    "preparation_minutes": self.item.preparation_minutes,
                    "available": "on",
                    "image_file": photo,
                },
            )

        self.assertRedirects(response, reverse("menu_list", args=["kitchen"]))
        self.item.refresh_from_db()
        self.assertEqual(self.item.image_url, "https://storage.test/menu/updated.png")
        store_image.assert_called_once()

    def test_reception_cannot_change_menu_services_or_device_configuration(self):
        reception = User.objects.create_user(username="reception", password="x")
        StaffProfile.objects.create(user=reception, role="reception")
        self.client.force_login(reception)
        for name, args in [
            ("menu_list", ["kitchen"]),
            ("menu_add", []),
            ("services", []),
            ("rooms", []),
            ("devices", []),
        ]:
            with self.subTest(page=name):
                response = self.client.get(reverse(name, args=args))
                self.assertEqual(response.status_code, 302)

    @patch("portal.views.store_menu_image", return_value="https://storage.test/menu/photo.png")
    def test_admin_menu_photo_upload_is_saved_and_returned_to_guest_menu(
        self, store_image
    ):
        self.client.force_login(self.admin)
        photo = SimpleUploadedFile(
            "jollof.png",
            b"\x89PNG\r\n\x1a\nphoto-bytes",
            content_type="image/png",
        )
        response = self.client.post(
            reverse("menu_add"),
            {
                "name": "Jollof Photo",
                "department": "kitchen",
                "category": "Main",
                "description": "Freshly prepared.",
                "price": "2500",
                "preparation_minutes": "20",
                "available": "on",
                "image_file": photo,
            },
        )
        self.assertRedirects(response, reverse("menu_list", args=["kitchen"]))
        item = MenuItem.objects.get(name="Jollof Photo")
        self.assertEqual(item.image_url, "https://storage.test/menu/photo.png")
        store_image.assert_called_once()
        payload = self.client.get(
            reverse("api_device_menu"), HTTP_X_DEVICE_ID=self.device.device_id
        ).json()["items"]
        self.assertEqual(
            next(entry for entry in payload if entry["id"] == item.pk)["image_url"],
            item.image_url,
        )

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

    def test_order_notification_message_contains_sender_and_department_items(self):
        bar_item = MenuItem.objects.create(
            name="Mango Mocktail",
            department="bar",
            category="Drinks",
            price=Decimal("3000.00"),
        )
        order = Order.objects.create(
            device=self.device,
            sender_name="Jane Customer",
            service_charge=Decimal("800.00"),
        )
        OrderLine.objects.create(
            order=order,
            menu_item=self.item,
            item_name=self.item.name,
            unit_price=self.item.price,
            quantity=1,
        )
        OrderLine.objects.create(
            order=order,
            menu_item=bar_item,
            item_name=bar_item.name,
            unit_price=bar_item.price,
            quantity=1,
        )

        kitchen_message = order_notification_text(order, "kitchen")
        bar_message = order_notification_text(order, "bar")

        self.assertIn("Sender name: Jane Customer", kitchen_message)
        self.assertIn("Jollof Rice x1", kitchen_message)
        self.assertNotIn("Mango Mocktail", kitchen_message)
        self.assertIn("Mango Mocktail x1", bar_message)
        self.assertNotIn("Jollof Rice", bar_message)

    def test_whatsapp_links_normalize_local_mobile_numbers(self):
        self.assertEqual(whatsapp_number("+234 801 234 5678"), "2348012345678")
        self.assertEqual(whatsapp_number("08012345678"), "2348012345678")
        self.assertEqual(whatsapp_number("8012345678"), "2348012345678")
        self.assertEqual(whatsapp_link("invalid", "message"), "")
        self.assertIn(
            "https://wa.me/2348012345678?text=",
            whatsapp_link("08012345678", "Sender name: Jane Customer"),
        )

    def test_dashboard_activity_shows_department_whatsapp_send_links(self):
        bar_item = MenuItem.objects.create(
            name="Mango Mocktail",
            department="bar",
            category="Drinks",
            price=Decimal("3000.00"),
        )
        kitchen_staff_user = User.objects.create_user(
            username="kitchen.staff",
            first_name="Kemi",
            password="Strong-Staff-Passphrase-2891",
        )
        bar_staff_user = User.objects.create_user(
            username="bar.staff",
            first_name="Tunde",
            password="Strong-Staff-Passphrase-2891",
        )
        kitchen_staff = StaffProfile.objects.create(
            user=kitchen_staff_user,
            role="handler",
            phone_number="+234 801 111 2222",
        )
        bar_staff = StaffProfile.objects.create(
            user=bar_staff_user,
            role="handler",
            phone_number="+234 802 333 4444",
        )
        ShiftAssignment.objects.create(
            shift="morning", department="kitchen", staff=kitchen_staff
        )
        ShiftAssignment.objects.create(
            shift="morning", department="bar", staff=bar_staff
        )
        order_response = self.client.post(
            reverse("api_create_order"),
            data=json.dumps(
                {
                    "device_id": self.device.device_id,
                    "sender_name": "Jane Customer",
                    "expected_total": 8800,
                    "items": [
                        {"item_id": self.item.pk, "quantity": 1},
                        {"item_id": bar_item.pk, "quantity": 1},
                    ],
                }
            ),
            content_type="application/json",
        )
        self.assertEqual(order_response.status_code, 201)
        self.assertNotIn("2348011112222", order_response.content.decode())
        self.assertNotIn("2348023334444", order_response.content.decode())
        self.client.force_login(self.admin)

        dashboard = self.client.get(reverse("dashboard"))
        activity = self.client.get(reverse("dashboard_activity"))

        self.assertContains(dashboard, "Payment confirmation messages")
        self.assertContains(dashboard, "Live · refreshes every 8 seconds")
        self.assertContains(dashboard, "Jane Customer")
        self.assertContains(activity, "https://wa.me/2348011112222")
        self.assertContains(activity, "https://wa.me/2348023334444")
        self.assertContains(activity, "Jollof Rice")
        self.assertContains(activity, "Mango Mocktail")
        self.assertContains(activity, "Open WhatsApp to send")

    def test_dashboard_activity_requires_an_operations_login(self):
        response = self.client.get(reverse("dashboard_activity"))
        self.assertEqual(response.status_code, 302)

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
        self.assertIn("no whatsapp message was sent", attempt.detail.lower())

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
