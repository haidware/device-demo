from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

from django.conf import settings
from django.urls import reverse


def guest_order_qr_url(request, device_id):
    base_url = settings.GUEST_ORDER_BASE_URL or request.build_absolute_uri(
        reverse("guest_order")
    )
    parts = urlsplit(base_url)
    if parts.scheme not in {"http", "https"} or not parts.netloc:
        raise ValueError("GUEST_ORDER_BASE_URL must be an absolute HTTP(S) URL.")
    query = dict(parse_qsl(parts.query, keep_blank_values=True))
    query["device_id"] = str(device_id)
    return urlunsplit((parts.scheme, parts.netloc, parts.path, urlencode(query), ""))
