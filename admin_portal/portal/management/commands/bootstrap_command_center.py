import os

from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction


class Command(BaseCommand):
    help = "Create or update the configured platform superuser."

    @transaction.atomic
    def handle(self, *args, **options):
        username = os.environ.get("SUPER_USER_LOGIN_USERNAME", "").strip()
        password = os.environ.get("SUPER_USER_LOGIN_KEY", "")
        if not username and not password:
            self.stdout.write("Platform superuser bootstrap is not configured; skipped.")
            return
        if not username or not password:
            raise CommandError(
                "Set both SUPER_USER_LOGIN_USERNAME and SUPER_USER_LOGIN_KEY."
            )

        User = get_user_model()
        user = User._default_manager.filter(username=username).first()
        if user is not None and not user.is_superuser:
            raise CommandError(
                "The configured platform username already belongs to a non-superuser. "
                "Choose a different username; the existing account was not changed."
            )

        if user is None:
            user = User(username=username)
        try:
            validate_password(password, user=user)
        except ValidationError as error:
            raise CommandError(
                "SUPER_USER_LOGIN_KEY does not meet the configured password "
                "requirements."
            ) from error

        if user.pk is None:
            user = User._default_manager.create_superuser(
                username=username, password=password
            )
            self.stdout.write("Created the configured platform superuser.")
        else:
            user.set_password(password)
            user.save(update_fields=["password"])
            self.stdout.write("Updated the configured platform superuser password.")
