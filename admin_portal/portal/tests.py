import json
from decimal import Decimal
from io import BytesIO
from urllib.error import HTTPError
from unittest.mock import MagicMock, patch

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.urls import reverse

from .menu_images import MenuImageStorageError, store_menu_image
from .models import (
    Device,
    MenuItem,
    Order,
    OrderLine,
    PortalSettings,
    Room,
    ServiceOption,
    ServiceRequest,
    ShiftAssignment,
    StaffProfile,
    WhatsAppAttempt,
)
from .whatsapp_links import order_notification_text, whatsapp_link, whatsapp_number

User = get_user_model()


class PortalFlowTests(TestCase):
    def setUp(self):
        self.property = PortalSettings.objects.create(
            property_name="Test Hotel", property_location="Lagos"
        )
        self.admin = User.objects.create_superuser(
            username="admin", email="admin@example.test", password="SecurePass123!test"
        )
        self.room = Room.objects.create(property=self.property, identifier="101")
        self.device = Device.objects.create(
            property=self.property,
            name="Room 101 tablet",
            device_id="123456",
            room=self.room,
        )
        self.item = MenuItem.objects.create(
            property=self.property,
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
                "phone_number": "+234 801 234 5678",
                "property_name": "Harbor Lounge",
                "property_location": "Victoria Island, Lagos",
                "password1": "Unique-Manager-Passphrase-2841",
                "password2": "Unique-Manager-Passphrase-2841",
            },
        )

        self.assertRedirects(response, reverse("dashboard"))
        manager = User.objects.get(username="property.manager")
        self.assertEqual(manager.staff_profile.role, "manager")
        property_settings = manager.staff_profile.property
        self.assertEqual(property_settings.property_name, "Harbor Lounge")
        self.assertEqual(property_settings.property_location, "Victoria Island, Lagos")
        self.assertRegex(property_settings.property_id, r"^HDW-\d{6,}$")
        self.assertEqual(manager.staff_profile.phone_number, "+234 801 234 5678")
        self.assertFalse(property_settings.subscription_confirmed)
        self.assertIn("_auth_user_id", self.client.session)

    def test_command_center_lists_properties_and_manages_subscription_and_account(self):
        manager_user = User.objects.create_user(
            username="command.manager",
            email="manager@command.test",
            password="Strong-Command-Manager-Passphrase-2841",
            first_name="Morgan",
            last_name="Manager",
        )
        StaffProfile.objects.create(
            user=manager_user,
            property=self.property,
            role="manager",
            phone_number="+234 802 111 2222",
        )
        self.client.force_login(self.admin)

        page = self.client.get("/commandcenter")

        self.assertEqual(page.status_code, 200)
        self.assertContains(page, self.property.property_id)
        self.assertContains(page, "manager@command.test")
        self.assertContains(page, "+234 802 111 2222")
        self.assertContains(page, "Properties onboarded")

        confirm = self.client.post(
            reverse("command_center_action", args=[self.property.pk]),
            {"action": "confirm_subscription"},
        )
        self.assertRedirects(confirm, reverse("command_center"))
        self.property.refresh_from_db()
        self.assertTrue(self.property.subscription_confirmed)
        self.assertIsNotNone(self.property.subscription_confirmed_at)

        reset = self.client.post(
            reverse("command_center_action", args=[self.property.pk]),
            {"action": "revoke_subscription"},
        )
        self.assertRedirects(reset, reverse("command_center"))
        self.property.refresh_from_db()
        self.assertFalse(self.property.subscription_confirmed)
        self.assertIsNone(self.property.subscription_confirmed_at)

        deactivate = self.client.post(
            reverse("command_center_action", args=[self.property.pk]),
            {"action": "deactivate"},
        )
        self.assertRedirects(deactivate, reverse("command_center"))
        self.property.refresh_from_db()
        self.assertFalse(self.property.is_active)
        self.assertTrue(Room.objects.filter(pk=self.room.pk).exists())
        self.assertTrue(User.objects.filter(pk=manager_user.pk).exists())
        self.assertEqual(
            self.client.post(
                reverse("api_device_session"),
                data=json.dumps({"device_id": self.device.device_id}),
                content_type="application/json",
            ).status_code,
            403,
        )
        self.client.force_login(manager_user)
        self.assertEqual(
            self.client.get(reverse("menu_list", args=["kitchen"])).status_code,
            302,
        )

        self.client.force_login(self.admin)
        reactivate = self.client.post(
            reverse("command_center_action", args=[self.property.pk]),
            {"action": "reactivate"},
        )
        self.assertRedirects(reactivate, reverse("command_center"))
        self.property.refresh_from_db()
        self.assertTrue(self.property.is_active)
        self.assertEqual(
            self.client.post(
                reverse("api_device_session"),
                data=json.dumps({"device_id": self.device.device_id}),
                content_type="application/json",
            ).status_code,
            200,
        )

    def test_command_center_is_superuser_only_and_actions_require_post(self):
        administrator = User.objects.create_user(
            username="not.command.admin",
            password="Strong-Portal-Admin-Passphrase-2841",
        )
        StaffProfile.objects.create(
            user=administrator, property=self.property, role="admin"
        )
        self.client.force_login(administrator)
        response = self.client.get(reverse("command_center"))
        self.assertEqual(response.status_code, 302)
        action_response = self.client.get(
            reverse("command_center_action", args=[self.property.pk])
        )
        self.assertEqual(action_response.status_code, 302)

    def test_manager_can_create_admin_account_and_set_bank_details(self):
        manager = User.objects.create_user(
            username="manager",
            password="Strong-Manager-Passphrase-2841",
        )
        StaffProfile.objects.create(user=manager, property=self.property, role="manager")
        self.client.force_login(manager)

        staff_response = self.client.post(
            reverse("staff_admin_add"),
            {
                "username": "testing.admin",
                "password": "Strong-Admin-Passphrase-9281",
                "phone_number": "+234 801 234 5678",
            },
        )
        self.assertRedirects(staff_response, reverse("dashboard"))
        self.assertEqual(
            User.objects.get(username="testing.admin").staff_profile.role,
            "admin",
        )

        settings_response = self.client.post(
            reverse("settings"),
            {
                "property_name": "Demo Hotel",
                "property_location": "Lagos",
                "currency": "NGN",
                "bank_name": "Demo Bank",
                "account_name": "Demo Hotel Ltd",
                "account_number": "0123456789",
                "active_shift": "morning",
                "whatsapp_enabled": "on",
            },
        )
        self.assertRedirects(settings_response, reverse("settings"))
        property_settings = self.property
        property_settings.refresh_from_db()
        self.assertEqual(property_settings.account_number, "0123456789")
        self.assertEqual(property_settings.property_location, "Lagos")

    def test_manager_only_sees_admin_setup_and_payment_settings(self):
        manager = User.objects.create_user(
            username="portal.manager",
            password="Strong-Manager-Passphrase-9281",
        )
        StaffProfile.objects.create(user=manager, property=self.property, role="manager")
        self.client.force_login(manager)

        response = self.client.get(reverse("dashboard"))

        self.assertContains(response, reverse("staff_admin_add"))
        self.assertContains(response, reverse("settings"))
        self.assertNotContains(response, reverse("menu_list", args=["kitchen"]))
        self.assertNotContains(response, reverse("orders"))

        for name, args in [
            ("menu_list", ["kitchen"]),
            ("menu_list", ["bar"]),
            ("services", []),
            ("staff_shifts", []),
            ("rooms", []),
            ("devices", []),
            ("staff", []),
        ]:
            with self.subTest(page=name, args=args):
                self.assertEqual(
                    self.client.get(reverse(name, args=args)).status_code,
                    302,
                )
        self.assertEqual(self.client.get(reverse("settings")).status_code, 200)
        self.assertEqual(self.client.get(reverse("staff_admin_add")).status_code, 200)

    def test_admin_can_edit_service_description_and_department(self):
        service = ServiceOption.objects.create(
            property=self.property,
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
        StaffProfile.objects.create(user=site_admin, property=self.property, role="admin")
        self.client.force_login(site_admin)
        create_response = self.client.post(
            reverse("staff_admin_add"),
            {
                "username": "unauthorized.admin",
                "password": "Strong-Admin-Passphrase-9281",
                "phone_number": "+234 801 234 5678",
            },
        )
        self.assertEqual(create_response.status_code, 302)
        self.assertFalse(User.objects.filter(username="unauthorized.admin").exists())
        settings_response = self.client.get(reverse("settings"))
        self.assertEqual(settings_response.status_code, 302)
        self.assertEqual(PortalSettings.objects.count(), 1)

    def test_only_administrator_can_manage_operations(self):
        manager = User.objects.create_user(
            username="operations.manager",
            password="Strong-Operations-Manager-9281",
        )
        StaffProfile.objects.create(user=manager, property=self.property, role="manager")
        reception = User.objects.create_user(
            username="operations.reception",
            password="Strong-Operations-Reception-9281",
        )
        StaffProfile.objects.create(user=reception, property=self.property, role="reception")
        administrator = User.objects.create_user(
            username="operations.admin",
            password="Strong-Operations-Admin-9281",
        )
        StaffProfile.objects.create(user=administrator, property=self.property, role="admin")

        for user in (manager, reception):
            with self.subTest(role=user.staff_profile.role):
                self.client.force_login(user)
                response = self.client.get(reverse("orders"))
                self.assertEqual(response.status_code, 302)

        self.client.force_login(administrator)
        self.assertEqual(self.client.get(reverse("orders")).status_code, 200)

    def test_admin_can_upload_photo_to_menu_item_edit(self):
        administrator = User.objects.create_user(
            username="photo.admin",
            password="Strong-Manager-Passphrase-2841",
        )
        StaffProfile.objects.create(user=administrator, property=self.property, role="admin")
        self.client.force_login(administrator)
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

    def test_admin_can_toggle_kitchen_and_bar_menu_availability(self):
        self.client.force_login(self.admin)
        bar_item = MenuItem.objects.create(
            property=self.property,
            name="Fresh juice",
            department="bar",
            category="Drinks",
            price=Decimal("1200.00"),
            preparation_minutes=5,
            available=False,
        )

        self.assertContains(
            self.client.get(reverse("menu_list", args=["kitchen"])),
            'aria-checked="true"',
        )
        self.assertContains(
            self.client.get(reverse("menu_list", args=["bar"])),
            'aria-checked="false"',
        )

        for item, expected_available in (
            (self.item, False),
            (bar_item, True),
        ):
            with self.subTest(department=item.department):
                response = self.client.post(
                    reverse("menu_toggle", args=[item.pk])
                )

                self.assertRedirects(
                    response,
                    reverse("menu_list", args=[item.department]),
                )
                item.refresh_from_db()
                self.assertEqual(item.available, expected_available)

    def test_menu_availability_toggle_requires_post(self):
        self.client.force_login(self.admin)

        response = self.client.get(reverse("menu_toggle", args=[self.item.pk]))

        self.assertEqual(response.status_code, 405)
        self.item.refresh_from_db()
        self.assertTrue(self.item.available)

    @override_settings(
        SUPABASE_URL="https://rgbqfzirecifubptdfqk.supabase.co",
        SUPABASE_SERVICE_ROLE_KEY="test-service-role-key",
        SUPABASE_STORAGE_BUCKET="menu-images",
    )
    @patch(
        "portal.menu_images.urllib.request.urlopen",
        side_effect=HTTPError(
            "https://rgbqfzirecifubptdfqk.supabase.co/storage/v1/object/menu-images",
            404,
            "Not Found",
            hdrs=None,
            fp=BytesIO(b'{"statusCode":"404","message":"Bucket not found"}'),
        ),
    )
    def test_supabase_upload_error_shows_provider_rejection_reason(self, urlopen):
        image = SimpleUploadedFile(
            "photo.png",
            b"\x89PNG\r\n\x1a\nphoto-bytes",
            content_type="image/png",
        )

        with self.assertRaises(MenuImageStorageError) as raised:
            store_menu_image(image)

        self.assertIn("HTTP 404", str(raised.exception))
        self.assertIn("Bucket not found", str(raised.exception))

    def test_reception_cannot_change_menu_services_or_device_configuration(self):
        reception = User.objects.create_user(username="reception", password="x")
        StaffProfile.objects.create(user=reception, property=self.property, role="reception")
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
            f"http://testserver{reverse('api_menu_image', args=[item.pk])}?device_id={self.device.device_id}",
        )

    @override_settings(
        SUPABASE_URL="https://rgbqfzirecifubptdfqk.supabase.co",
        SUPABASE_STORAGE_BUCKET="menu-images",
    )
    @patch("portal.api.urlopen")
    def test_menu_image_is_proxied_from_supabase_on_same_origin(self, urlopen):
        self.item.image_url = (
            "https://rgbqfzirecifubptdfqk.supabase.co/storage/v1/object/"
            "public/menu-images/menu/jollof.png"
        )
        self.item.save(update_fields=["image_url"])
        upstream_response = MagicMock()
        upstream_response.headers.get_content_type.return_value = "image/png"
        upstream_response.read.return_value = b"\x89PNG\r\n\x1a\nimage-bytes"
        urlopen.return_value.__enter__.return_value = upstream_response

        response = self.client.get(
            reverse("api_menu_image", args=[self.item.pk]),
            {"device_id": self.device.device_id},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response["Content-Type"], "image/png")
        self.assertEqual(response["X-Content-Type-Options"], "nosniff")
        self.assertEqual(response.content, b"\x89PNG\r\n\x1a\nimage-bytes")
        urlopen.assert_called_once()

    @override_settings(
        SUPABASE_URL="https://rgbqfzirecifubptdfqk.supabase.co",
        SUPABASE_STORAGE_BUCKET="menu-images",
    )
    @patch("portal.api.urlopen")
    def test_menu_image_proxy_rejects_external_image_hosts(self, urlopen):
        self.item.image_url = "https://untrusted.example/image.png"
        self.item.save(update_fields=["image_url"])

        response = self.client.get(
            reverse("api_menu_image", args=[self.item.pk]),
            {"device_id": self.device.device_id},
        )

        self.assertEqual(response.status_code, 502)
        urlopen.assert_not_called()

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
            property=self.property,
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
        self.property.property_name = "Demo Hotel"
        self.property.property_location = "Victoria Island, Lagos"
        self.property.bank_name = "GTBank"
        self.property.account_name = "Demo Hotel Ltd"
        self.property.account_number = "0123456789"
        self.property.save()
        response = self.client.post(
            reverse("api_device_session"),
            data=json.dumps({"device_id": "123456"}),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["room"], "101")
        self.assertEqual(
            response.json()["property"],
            {"name": "Demo Hotel", "location": "Victoria Island, Lagos"},
        )
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
        self.assertTrue(device.is_qr_device)

    def test_device_registration_generates_id_and_creates_room_number(self):
        self.client.force_login(self.admin)
        response = self.client.post(
            reverse("device_add"),
            {
                "name": "Room 101 ordering tablet",
                "room_identifier": "205",
                "active": "on",
            },
        )
        self.assertRedirects(response, reverse("devices"))
        device = Device.objects.get(name="Room 101 ordering tablet")
        self.assertRegex(device.device_id, r"^\d{10}$")
        self.assertEqual(device.room.identifier, "205")

    def test_device_registration_reuses_existing_room_number(self):
        self.client.force_login(self.admin)
        response = self.client.post(
            reverse("device_add"),
            {
                "name": "Second Room 101 tablet",
                "room_identifier": "101",
                "active": "on",
            },
        )
        self.assertRedirects(response, reverse("devices"))
        device = Device.objects.get(name="Second Room 101 tablet")
        self.assertEqual(device.room, self.room)
        self.assertEqual(Room.objects.filter(identifier="101").count(), 1)

    def test_generated_device_id_signs_in_to_its_assigned_room(self):
        self.client.force_login(self.admin)
        response = self.client.post(
            reverse("device_add"),
            {
                "name": "Room 205 ordering tablet",
                "room_identifier": "205",
                "active": "on",
            },
        )
        self.assertRedirects(response, reverse("devices"))
        device = Device.objects.get(name="Room 205 ordering tablet")

        sign_in_response = self.client.post(
            reverse("api_device_session"),
            data=json.dumps({"device_id": device.device_id}),
            content_type="application/json",
        )

        self.assertEqual(sign_in_response.status_code, 200)
        self.assertEqual(sign_in_response.json()["device_id"], device.device_id)
        self.assertEqual(sign_in_response.json()["room"], "205")

    def test_menu_api_only_exposes_admin_available_items(self):
        available_bar_item = MenuItem.objects.create(
            property=self.property,
            name="Available Juice",
            department="bar",
            category="Drinks",
            price=Decimal("1500.00"),
        )
        unavailable_kitchen_item = MenuItem.objects.create(
            property=self.property,
            name="Hidden Soup",
            department="kitchen",
            category="Soup",
            price=Decimal("1200.00"),
            available=False,
        )
        unavailable_bar_item = MenuItem.objects.create(
            property=self.property,
            name="Hidden Cocktail",
            department="bar",
            category="Drinks",
            price=Decimal("2000.00"),
            available=False,
        )
        response = self.client.get(
            reverse("api_device_menu"),
            HTTP_X_DEVICE_ID="123456",
        )
        self.assertEqual(response.status_code, 200)
        item_ids = {entry["id"] for entry in response.json()["items"]}
        self.assertIn(self.item.pk, item_ids)
        self.assertIn(available_bar_item.pk, item_ids)
        self.assertNotIn(unavailable_kitchen_item.pk, item_ids)
        self.assertNotIn(unavailable_bar_item.pk, item_ids)
        item_payload = next(
            entry
            for entry in response.json()["items"]
            if entry["id"] == available_bar_item.pk
        )
        self.assertEqual(item_payload["name"], "Available Juice")
        self.assertEqual(item_payload["description"], "")
        self.assertEqual(item_payload["price"], "1500.00")
        self.assertEqual(item_payload["estimated_minutes"], 25)
        self.assertTrue(item_payload["available"])
        self.assertIsNone(item_payload["image_url"])
        departments = {entry["department"] for entry in response.json()["items"]}
        self.assertEqual(departments, {"kitchen", "bar"})

    def test_device_apis_only_expose_and_accept_its_property_data(self):
        other_property = PortalSettings.objects.create(
            property_name="Other Hotel",
            property_location="Abuja",
            bank_name="Other Bank",
            account_name="Other Hotel Ltd",
            account_number="9999999999",
        )
        other_room = Room.objects.create(property=other_property, identifier="202")
        other_device = Device.objects.create(
            property=other_property,
            name="Other room tablet",
            device_id="654321",
            room=other_room,
        )
        other_item = MenuItem.objects.create(
            property=other_property,
            name="Other Hotel Meal",
            department="kitchen",
            category="Main",
            price=Decimal("1000.00"),
            image_url="https://storage.test/private.png",
        )
        other_service = ServiceOption.objects.create(
            property=other_property,
            name="Other Hotel Service",
            department="housekeeping",
        )

        own_menu = self.client.get(
            reverse("api_device_menu"), HTTP_X_DEVICE_ID=self.device.device_id
        )
        other_menu = self.client.get(
            reverse("api_device_menu"), HTTP_X_DEVICE_ID=other_device.device_id
        )
        self.assertEqual(
            {item["id"] for item in own_menu.json()["items"]}, {self.item.pk}
        )
        self.assertEqual(
            {item["id"] for item in other_menu.json()["items"]}, {other_item.pk}
        )
        self.assertEqual(
            self.client.get(
                reverse("api_device_services"),
                HTTP_X_DEVICE_ID=self.device.device_id,
            ).json()["services"],
            [],
        )
        self.assertEqual(
            self.client.get(
                reverse("api_menu_image", args=[other_item.pk]),
                {"device_id": self.device.device_id},
            ).status_code,
            404,
        )

        session = self.client.post(
            reverse("api_device_session"),
            data=json.dumps({"device_id": other_device.device_id}),
            content_type="application/json",
        )
        self.assertEqual(session.json()["property"]["name"], "Other Hotel")
        self.assertEqual(
            session.json()["payment_details"]["account_number"], "9999999999"
        )

        order_response = self.client.post(
            reverse("api_create_order"),
            data=json.dumps(
                {
                    "device_id": self.device.device_id,
                    "sender_name": "Jane Customer",
                    "expected_total": 1100,
                    "items": [{"item_id": other_item.pk, "quantity": 1}],
                }
            ),
            content_type="application/json",
        )
        self.assertEqual(order_response.status_code, 400)
        self.assertFalse(Order.objects.filter(property=self.property).exists())

        service_response = self.client.post(
            reverse("api_create_service_request"),
            data=json.dumps(
                {
                    "device_id": self.device.device_id,
                    "service_id": other_service.pk,
                }
            ),
            content_type="application/json",
        )
        self.assertEqual(service_response.status_code, 400)
        self.assertFalse(ServiceRequest.objects.filter(property=self.property).exists())

    def test_staff_cannot_access_or_change_another_property_records(self):
        other_property = PortalSettings.objects.create(property_name="Other Hotel")
        other_item = MenuItem.objects.create(
            property=other_property,
            name="Private Menu Item",
            department="bar",
            category="Drinks",
            price=Decimal("900.00"),
        )
        other_device = Device.objects.create(
            property=other_property, name="Other tablet", device_id="999999"
        )
        other_order = Order.objects.create(
            property=other_property, device=other_device
        )
        administrator = User.objects.create_user(
            username="tenant.admin",
            password="Strong-Tenant-Admin-Passphrase-2841",
        )
        StaffProfile.objects.create(
            user=administrator, property=self.property, role="admin"
        )
        self.client.force_login(administrator)

        kitchen_response = self.client.get(reverse("menu_list", args=["kitchen"]))
        self.assertContains(kitchen_response, self.item.name)
        self.assertNotContains(kitchen_response, other_item.name)
        orders_response = self.client.get(reverse("orders"))
        self.assertNotContains(orders_response, other_order.order_number)
        self.assertEqual(
            self.client.get(
                reverse("order_detail", args=[other_order.pk])
            ).status_code,
            404,
        )
        self.assertEqual(
            self.client.post(reverse("menu_toggle", args=[other_item.pk])).status_code,
            404,
        )
        other_item.refresh_from_db()
        self.assertTrue(other_item.available)

    def test_order_submission_rejects_items_made_unavailable(self):
        self.item.available = False
        self.item.save(update_fields=["available"])

        response = self.client.post(
            reverse("api_create_order"),
            data=json.dumps(
                {
                    "device_id": self.device.device_id,
                    "sender_name": "Jane Customer",
                    "expected_total": 5500,
                    "items": [{"item_id": self.item.pk, "quantity": 1}],
                }
            ),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()["error"], "One or more items are unavailable.")
        self.assertFalse(Order.objects.exists())

    def test_device_services_returns_only_active_services(self):
        active_service = ServiceOption.objects.create(
            property=self.property,
            name="Fresh Towels",
            department="housekeeping",
            description="Delivered to your room.",
        )
        ServiceOption.objects.create(
            property=self.property,
            name="Late Checkout",
            department="reception",
            active=False,
        )

        response = self.client.get(
            reverse("api_device_services"),
            HTTP_X_DEVICE_ID=self.device.device_id,
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json()["services"],
            [
                {
                    "id": active_service.pk,
                    "name": "Fresh Towels",
                    "department": "housekeeping",
                    "description": "Delivered to your room.",
                }
            ],
        )

    def test_device_can_submit_service_request_for_its_assigned_room(self):
        service = ServiceOption.objects.create(
            property=self.property,
            name="Fresh Towels",
            department="housekeeping",
        )

        response = self.client.post(
            reverse("api_create_service_request"),
            data=json.dumps(
                {
                    "device_id": self.device.device_id,
                    "service_id": service.pk,
                }
            ),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 201)
        request_record = ServiceRequest.objects.get()
        self.assertEqual(request_record.device, self.device)
        self.assertEqual(request_record.service, service)
        self.assertEqual(request_record.room_identifier, self.room.identifier)

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
            property=self.property,
            name="Mango Mocktail",
            department="bar",
            category="Drinks",
            price=Decimal("3000.00"),
        )
        order = Order.objects.create(
            property=self.property,
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
            property=self.property,
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
            property=self.property,
            role="kitchen_staff",
            departments="Kitchen",
            phone_number="+234 801 111 2222",
        )
        bar_staff = StaffProfile.objects.create(
            user=bar_staff_user,
            property=self.property,
            role="bar_staff",
            departments="Bar",
            phone_number="+234 802 333 4444",
        )
        ShiftAssignment.objects.create(
            property=self.property,
            shift="morning", department="kitchen", staff=kitchen_staff
        )
        ShiftAssignment.objects.create(
            property=self.property,
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

    def test_administrator_can_confirm_payment(self):
        administrator = User.objects.create_user(
            username="payment.admin",
            password="Strong-Payment-Admin-9281",
        )
        StaffProfile.objects.create(user=administrator, property=self.property, role="admin")
        self.client.force_login(administrator)
        order = Order.objects.create(
            property=self.property,
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
        self.assertEqual(order.payment_confirmed_by, administrator)

    def test_staff_registration_saves_name_role_and_contact(self):
        self.client.force_login(self.admin)
        response = self.client.post(
            reverse("staff_add"),
            {
                "username": "kitchen.staff",
                "first_name": "Kitchen",
                "last_name": "Staff",
                "password": "Strong-Unique-Passphrase-9281",
                "role": "kitchen_staff",
                "departments": "Kitchen",
                "phone_number": "+234 801 234 5678",
            },
        )
        self.assertRedirects(response, reverse("staff"))
        profile = StaffProfile.objects.get(user__username="kitchen.staff")
        self.assertEqual(profile.phone_number, "+234 801 234 5678")
        self.assertEqual(profile.role, "kitchen_staff")
        self.assertEqual(profile.departments, "Kitchen")

    def test_staff_role_dropdown_only_offers_department_staff_roles(self):
        self.client.force_login(self.admin)

        response = self.client.get(reverse("staff_add"))

        self.assertContains(response, "Kitchen Staff")
        self.assertContains(response, "Bar Staff")
        self.assertContains(response, "Service Staff")
        self.assertNotContains(response, "Administrator</option>")
        self.assertNotContains(response, "Order Handler</option>")

    def test_manager_can_create_admin_login_separately_from_staff_roles(self):
        manager = User.objects.create_user(
            username="admin.creator",
            password="Strong-Admin-Creator-9281",
        )
        StaffProfile.objects.create(user=manager, property=self.property, role="manager")
        self.client.force_login(manager)

        response = self.client.post(
            reverse("staff_admin_add"),
            {
                "username": "new.admin",
                "password": "Strong-Admin-Passphrase-9281",
                "phone_number": "+234 801 234 5678",
            },
        )

        self.assertRedirects(response, reverse("dashboard"))
        self.assertEqual(
            User.objects.get(username="new.admin").staff_profile.role,
            "admin",
        )

    def test_staff_registration_rejects_invalid_contact_number(self):
        self.client.force_login(self.admin)
        response = self.client.post(
            reverse("staff_add"),
            {
                "username": "staff.invalid",
                "password": "Strong-Unique-Passphrase-9281",
                "role": "service_staff",
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
            user=staff_user,
            property=self.property,
            role="handler",
            phone_number="+234 801 234 5678",
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
        order = Order.objects.create(property=self.property, device=self.device)
        staff_user = User.objects.create_user(
            username="handler", password="Strong-Unique-Passphrase-9281"
        )
        StaffProfile.objects.create(
            user=staff_user, property=self.property, role="handler"
        )
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
        device = Device.objects.get(room=self.room, active=True, is_qr_device=True)
        self.assertNotEqual(device.device_id, "123456")

        qr_page = self.client.get(reverse("room_qr", args=[self.room.pk]))
        self.assertContains(qr_page, "confirmation flow as the device, in a browser")
        self.assertContains(
            qr_page,
            f"http://testserver/?device_id={device.device_id}",
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

    @override_settings(GUEST_ORDER_BASE_URL="http://192.168.0.127:8000/")
    def test_qr_uses_configured_guest_order_base_url(self):
        self.client.force_login(self.admin)
        response = self.client.post(reverse("room_qr", args=[self.room.pk]))
        self.assertRedirects(response, reverse("room_qr", args=[self.room.pk]))
        qr_device = self.room.__class__.objects.get(pk=self.room.pk).active_qr_device
        response = self.client.get(reverse("room_qr", args=[self.room.pk]))
        self.assertContains(
            response,
            f"http://192.168.0.127:8000/?device_id={qr_device.device_id}",
        )

    @override_settings(GUEST_ORDER_BASE_URL="https://device-demo.onrender.com/admin/")
    def test_qr_always_opens_ordering_homepage_even_with_admin_path_configured(self):
        self.client.force_login(self.admin)
        response = self.client.post(reverse("room_qr", args=[self.room.pk]))
        self.assertRedirects(response, reverse("room_qr", args=[self.room.pk]))
        qr_device = self.room.__class__.objects.get(pk=self.room.pk).active_qr_device
        response = self.client.get(reverse("room_qr", args=[self.room.pk]))

        self.assertContains(
            response,
            f"https://device-demo.onrender.com/?device_id={qr_device.device_id}",
        )

    def test_regenerating_room_qr_reuses_active_device(self):
        self.client.force_login(self.admin)
        for _ in range(2):
            response = self.client.post(reverse("room_qr", args=[self.room.pk]))
            self.assertRedirects(response, reverse("room_qr", args=[self.room.pk]))
        self.assertEqual(
            Device.objects.filter(
                room=self.room, active=True, is_qr_device=True
            ).count(),
            1,
        )

    def test_room_qr_uses_separate_access_id_from_physical_device(self):
        self.client.force_login(self.admin)
        response = self.client.post(reverse("room_qr", args=[self.room.pk]))
        self.assertRedirects(response, reverse("room_qr", args=[self.room.pk]))

        qr_device = self.room.active_qr_device
        self.assertIsNotNone(qr_device)
        self.assertNotEqual(qr_device.pk, self.device.pk)
        self.assertNotEqual(qr_device.device_id, self.device.device_id)
        self.assertTrue(qr_device.is_qr_device)

        device_list = self.client.get(reverse("devices"))
        self.assertContains(device_list, self.device.device_id)
        self.assertNotContains(device_list, qr_device.device_id)

        session = self.client.post(
            reverse("api_device_session"),
            data=json.dumps({"device_id": qr_device.device_id}),
            content_type="application/json",
        )
        self.assertEqual(session.status_code, 200)
        self.assertEqual(session.json()["room"], self.room.identifier)

    def test_only_admin_can_generate_room_qr(self):
        reception = User.objects.create_user(username="reception", password="test")
        StaffProfile.objects.create(
            user=reception, property=self.property, role="reception"
        )
        self.client.force_login(reception)
        response = self.client.post(reverse("room_qr", args=[self.room.pk]))
        self.assertEqual(response.status_code, 403)
        self.assertFalse(
            Device.objects.filter(room=self.room, is_qr_device=True).exists()
        )

    def test_unallowed_browser_origin_receives_no_cors_grant(self):
        response = self.client.options(
            reverse("api_device_menu"),
            HTTP_ORIGIN="https://untrusted.example",
        )
        self.assertNotIn("Access-Control-Allow-Origin", response.headers)
