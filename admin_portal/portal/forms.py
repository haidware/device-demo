from django import forms
from django.contrib.auth import get_user_model
from django.contrib.auth.forms import UserCreationForm
from django.contrib.auth.password_validation import validate_password
from django.db import transaction

from .models import (
    Device,
    generate_device_id,
    MenuItem,
    PortalSettings,
    Room,
    ServiceOption,
    StaffProfile,
)

User = get_user_model()


class RoomForm(forms.ModelForm):
    class Meta:
        model = Room
        fields = ["identifier", "room_type", "floor", "notes", "active"]
        labels = {"identifier": "Room / table number"}


class DeviceForm(forms.ModelForm):
    device_id = forms.CharField(
        label="System-assigned Device ID",
        required=False,
        disabled=True,
    )

    class Meta:
        model = Device
        fields = ["name", "room", "active"]
        widgets = {"room": forms.Select(attrs={"required": False})}

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        if self.instance.pk:
            self.fields["device_id"].initial = self.instance.device_id
        else:
            self.fields.pop("device_id")

    def save(self, commit=True):
        device = super().save(commit=False)
        if not device.pk:
            device.device_id = generate_device_id()
        if commit:
            device.save()
            self.save_m2m()
        return device


class MenuItemForm(forms.ModelForm):
    image_file = forms.FileField(
        label="Food or drink photo",
        required=False,
        widget=forms.ClearableFileInput(
            attrs={"accept": "image/jpeg,image/png,image/webp", "capture": "environment"}
        ),
        help_text="Take a photo or choose an image (JPEG, PNG, or WebP; up to 5 MB).",
    )

    class Meta:
        model = MenuItem
        fields = [
            "name",
            "department",
            "category",
            "description",
            "price",
            "preparation_minutes",
            "available",
        ]

    def save(self, commit=True):
        item = super().save(commit=False)
        if commit:
            item.save()
            self.save_m2m()
        return item


class ServiceOptionForm(forms.ModelForm):
    class Meta:
        model = ServiceOption
        fields = ["name", "department", "description", "active"]


class StaffCreateForm(forms.Form):
    username = forms.CharField(max_length=150)
    first_name = forms.CharField(max_length=150, required=False)
    last_name = forms.CharField(max_length=150, required=False)
    password = forms.CharField(widget=forms.PasswordInput, min_length=12)
    role = forms.ChoiceField(choices=StaffProfile.ROLES)
    departments = forms.CharField(max_length=160, required=False)
    phone_number = forms.CharField(max_length=24)

    def __init__(self, *args, allowed_roles=None, **kwargs):
        super().__init__(*args, **kwargs)
        if allowed_roles is not None:
            self.fields["role"].choices = allowed_roles

    def clean_password(self):
        password = self.cleaned_data["password"]
        validate_password(password)
        return password

    def clean_username(self):
        username = self.cleaned_data["username"]
        if User.objects.filter(username__iexact=username).exists():
            raise forms.ValidationError("That username is already in use.")
        return username

    def clean_phone_number(self):
        phone_number = self.cleaned_data["phone_number"].strip()
        allowed = set("0123456789 +-()")
        digits = [character for character in phone_number if character.isdigit()]
        if (
            not 7 <= len(digits) <= 15
            or any(character not in allowed for character in phone_number)
            or ("+" in phone_number and not phone_number.startswith("+"))
        ):
            raise forms.ValidationError(
                "Enter a valid contact number using 7 to 15 digits."
            )
        return phone_number

    @transaction.atomic
    def save(self):
        user = User.objects.create_user(
            username=self.cleaned_data["username"],
            first_name=self.cleaned_data["first_name"],
            last_name=self.cleaned_data["last_name"],
            password=self.cleaned_data["password"],
        )
        StaffProfile.objects.create(
            user=user,
            role=self.cleaned_data["role"],
            departments=self.cleaned_data["departments"],
            phone_number=self.cleaned_data["phone_number"].strip(),
        )
        return user


class PortalSettingsForm(forms.ModelForm):
    class Meta:
        model = PortalSettings
        fields = [
            "property_name",
            "currency",
            "bank_name",
            "account_name",
            "account_number",
            "active_shift",
            "whatsapp_enabled",
        ]


class ManagerSignupForm(UserCreationForm):
    email = forms.EmailField()
    first_name = forms.CharField(max_length=150)
    last_name = forms.CharField(max_length=150)

    class Meta:
        model = User
        fields = ["username", "first_name", "last_name", "email"]
