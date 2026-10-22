from django.db import migrations


def restrict_supabase_api_roles(apps, schema_editor):
    connection = schema_editor.connection
    if connection.vendor != "postgresql":
        return

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT COUNT(*)
            FROM pg_roles
            WHERE rolname IN ('anon', 'authenticated')
            """
        )
        if cursor.fetchone()[0] != 2:
            raise RuntimeError(
                "Supabase database roles 'anon' and 'authenticated' are required "
                "to restrict direct API access."
            )

        statements = (
            "REVOKE ALL ON SCHEMA public FROM PUBLIC, anon, authenticated",
            "REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public "
            "FROM PUBLIC, anon, authenticated",
            "REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public "
            "FROM PUBLIC, anon, authenticated",
            "ALTER DEFAULT PRIVILEGES IN SCHEMA public "
            "REVOKE ALL ON TABLES FROM PUBLIC, anon, authenticated",
            "ALTER DEFAULT PRIVILEGES IN SCHEMA public "
            "REVOKE ALL ON SEQUENCES FROM PUBLIC, anon, authenticated",
        )
        for statement in statements:
            cursor.execute(statement)
        cursor.execute(
            """
            SELECT schemaname, tablename
            FROM pg_tables
            WHERE schemaname = 'public'
            """
        )
        for schema_name, table_name in cursor.fetchall():
            cursor.execute(
                f"ALTER TABLE {schema_editor.quote_name(schema_name)}."
                f"{schema_editor.quote_name(table_name)} "
                "ENABLE ROW LEVEL SECURITY"
            )


class Migration(migrations.Migration):
    dependencies = [("portal", "0009_property_tenant_isolation")]

    operations = [
        migrations.RunPython(restrict_supabase_api_roles),
    ]
