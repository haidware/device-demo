import urllib.error
import urllib.parse
import urllib.request
import uuid

from django.conf import settings


MAX_MENU_IMAGE_BYTES = 5 * 1024 * 1024
IMAGE_SIGNATURES = {
    "image/jpeg": (".jpg", lambda content: content.startswith(b"\xff\xd8\xff")),
    "image/png": (".png", lambda content: content.startswith(b"\x89PNG\r\n\x1a\n")),
    "image/webp": (
        ".webp",
        lambda content: content.startswith(b"RIFF") and content[8:12] == b"WEBP",
    ),
}


class MenuImageStorageError(Exception):
    pass


def store_menu_image(uploaded_file):
    content_type = uploaded_file.content_type
    image_format = IMAGE_SIGNATURES.get(content_type)
    if image_format is None:
        raise MenuImageStorageError("Choose a JPEG, PNG, or WebP image.")

    uploaded_file.seek(0)
    content = uploaded_file.read(MAX_MENU_IMAGE_BYTES + 1)
    uploaded_file.seek(0)
    if len(content) > MAX_MENU_IMAGE_BYTES:
        raise MenuImageStorageError("The image must be 5 MB or smaller.")
    if not image_format[1](content):
        raise MenuImageStorageError("The uploaded file is not a valid image.")

    project_url = settings.SUPABASE_URL.rstrip("/")
    service_key = settings.SUPABASE_SERVICE_ROLE_KEY
    bucket = settings.SUPABASE_STORAGE_BUCKET
    if not project_url or not service_key:
        raise MenuImageStorageError(
            "Menu photo storage is not configured. Contact the system manager."
        )

    extension = image_format[0]
    object_path = f"menu/{uuid.uuid4().hex}{extension}"
    encoded_bucket = urllib.parse.quote(bucket, safe="")
    encoded_path = urllib.parse.quote(object_path, safe="/")
    request = urllib.request.Request(
        f"{project_url}/storage/v1/object/{encoded_bucket}/{encoded_path}",
        data=content,
        headers={
            "Authorization": f"Bearer {service_key}",
            "apikey": service_key,
            "Content-Type": content_type,
            "Cache-Control": "public, max-age=31536000, immutable",
            "x-upsert": "false",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            if not 200 <= response.status < 300:
                raise MenuImageStorageError(
                    "Supabase Storage could not save the image. Try again."
                )
    except urllib.error.HTTPError as error:
        raise MenuImageStorageError(
            "Supabase Storage rejected the image. Check the bucket configuration."
        ) from error
    except (urllib.error.URLError, TimeoutError) as error:
        raise MenuImageStorageError(
            "Could not connect to Supabase Storage. Try again."
        ) from error

    return (
        f"{project_url}/storage/v1/object/public/"
        f"{encoded_bucket}/{encoded_path}"
    )
