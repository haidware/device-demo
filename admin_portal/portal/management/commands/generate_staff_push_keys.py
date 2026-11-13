import base64

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = "Generate VAPID keys for browser push notifications."

    def handle(self, *args, **options):
        private_key = ec.generate_private_key(ec.SECP256R1())
        private_pem = private_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption(),
        )
        public_key = private_key.public_key().public_bytes(
            encoding=serialization.Encoding.X962,
            format=serialization.PublicFormat.UncompressedPoint,
        )
        self.stdout.write(
            "WEB_PUSH_VAPID_PUBLIC_KEY="
            + base64.urlsafe_b64encode(public_key).decode().rstrip("=")
        )
        self.stdout.write(
            "WEB_PUSH_VAPID_PRIVATE_KEY_B64="
            + base64.b64encode(private_pem).decode()
        )
        self.stdout.write("WEB_PUSH_VAPID_SUBJECT=mailto:replace-with-support-email")
        self.stdout.write(
            self.style.WARNING(
                "Keep WEB_PUSH_VAPID_PRIVATE_KEY_B64 secret. Do not commit it."
            )
        )
