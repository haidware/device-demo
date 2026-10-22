import django.db.models.deletion
from django.db import migrations, models


def assign_legacy_records(apps, schema_editor):
    PortalSettings = apps.get_model("portal", "PortalSettings")
    property_record = PortalSettings.objects.order_by("pk").first()
    model_names = (
        "Room",
        "Device",
        "MenuItem",
        "ServiceOption",
        "StaffProfile",
        "ShiftAssignment",
        "Order",
        "ServiceRequest",
        "WhatsAppAttempt",
    )
    models_to_assign = [
        apps.get_model("portal", model_name) for model_name in model_names
    ]
    if property_record is None and any(
        model.objects.exists() for model in models_to_assign
    ):
        property_record = PortalSettings.objects.create(
            property_name="HAIDWARE Hospitality"
        )
    if property_record is not None:
        for model in models_to_assign:
            model.objects.filter(property__isnull=True).update(
                property_id=property_record.pk
            )


class Migration(migrations.Migration):
    dependencies = [("portal", "0008_portalsettings_property_location")]

    operations = [
        migrations.RemoveConstraint(
            model_name="shiftassignment",
            name="unique_shift_department",
        ),
        migrations.AddField(
            model_name="device",
            name="property",
            field=models.ForeignKey(
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="devices",
                to="portal.portalsettings",
            ),
        ),
        migrations.AddField(
            model_name="menuitem",
            name="property",
            field=models.ForeignKey(
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="menu_items",
                to="portal.portalsettings",
            ),
        ),
        migrations.AddField(
            model_name="order",
            name="property",
            field=models.ForeignKey(
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="orders",
                to="portal.portalsettings",
            ),
        ),
        migrations.AddField(
            model_name="room",
            name="property",
            field=models.ForeignKey(
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="rooms",
                to="portal.portalsettings",
            ),
        ),
        migrations.AddField(
            model_name="serviceoption",
            name="property",
            field=models.ForeignKey(
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="service_options",
                to="portal.portalsettings",
            ),
        ),
        migrations.AddField(
            model_name="servicerequest",
            name="property",
            field=models.ForeignKey(
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="service_requests",
                to="portal.portalsettings",
            ),
        ),
        migrations.AddField(
            model_name="shiftassignment",
            name="property",
            field=models.ForeignKey(
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="shift_assignments",
                to="portal.portalsettings",
            ),
        ),
        migrations.AddField(
            model_name="staffprofile",
            name="property",
            field=models.ForeignKey(
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="staff_profiles",
                to="portal.portalsettings",
            ),
        ),
        migrations.AddField(
            model_name="whatsappattempt",
            name="property",
            field=models.ForeignKey(
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="whatsapp_attempts",
                to="portal.portalsettings",
            ),
        ),
        migrations.RunPython(assign_legacy_records, migrations.RunPython.noop),
        migrations.AlterField(
            model_name="device",
            name="property",
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.CASCADE,
                related_name="devices",
                to="portal.portalsettings",
            ),
        ),
        migrations.AlterField(
            model_name="menuitem",
            name="property",
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.CASCADE,
                related_name="menu_items",
                to="portal.portalsettings",
            ),
        ),
        migrations.AlterField(
            model_name="order",
            name="property",
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.CASCADE,
                related_name="orders",
                to="portal.portalsettings",
            ),
        ),
        migrations.AlterField(
            model_name="room",
            name="property",
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.CASCADE,
                related_name="rooms",
                to="portal.portalsettings",
            ),
        ),
        migrations.AlterField(
            model_name="serviceoption",
            name="property",
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.CASCADE,
                related_name="service_options",
                to="portal.portalsettings",
            ),
        ),
        migrations.AlterField(
            model_name="servicerequest",
            name="property",
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.CASCADE,
                related_name="service_requests",
                to="portal.portalsettings",
            ),
        ),
        migrations.AlterField(
            model_name="shiftassignment",
            name="property",
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.CASCADE,
                related_name="shift_assignments",
                to="portal.portalsettings",
            ),
        ),
        migrations.AlterField(
            model_name="staffprofile",
            name="property",
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.CASCADE,
                related_name="staff_profiles",
                to="portal.portalsettings",
            ),
        ),
        migrations.AlterField(
            model_name="whatsappattempt",
            name="property",
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.CASCADE,
                related_name="whatsapp_attempts",
                to="portal.portalsettings",
            ),
        ),
        migrations.AlterField(
            model_name="room",
            name="identifier",
            field=models.CharField(max_length=80),
        ),
        migrations.AddConstraint(
            model_name="room",
            constraint=models.UniqueConstraint(
                fields=("property", "identifier"),
                name="unique_property_room_identifier",
            ),
        ),
        migrations.AddConstraint(
            model_name="shiftassignment",
            constraint=models.UniqueConstraint(
                fields=("property", "shift", "department"),
                name="unique_property_shift_department",
            ),
        ),
    ]
