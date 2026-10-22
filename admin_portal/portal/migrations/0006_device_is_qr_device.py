from django.db import migrations, models


def mark_existing_qr_devices(apps, schema_editor):
    Device = apps.get_model("portal", "Device")
    Device.objects.filter(name__startswith="QR ·").update(is_qr_device=True)


class Migration(migrations.Migration):

    dependencies = [
        ("portal", "0005_menuitem_image_url_alter_staffprofile_role"),
    ]

    operations = [
        migrations.AddField(
            model_name="device",
            name="is_qr_device",
            field=models.BooleanField(default=False),
        ),
        migrations.RunPython(mark_existing_qr_devices, migrations.RunPython.noop),
    ]
