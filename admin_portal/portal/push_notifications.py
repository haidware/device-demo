import base64
import json
import logging

import requests
from django.conf import settings
from django.db import transaction
from py_vapid import VapidException
from pywebpush import WebPushException, webpush

from .models import StaffPushSubscription, WhatsAppAttempt

logger = logging.getLogger(__name__)


def schedule_staff_pushes(*, order=None, service_request=None):
    attempts = WhatsAppAttempt.objects.filter(
        order=order, service_request=service_request
    ).exclude(staff__isnull=True)
    for attempt_id in attempts.values_list("pk", flat=True):
        transaction.on_commit(
            lambda attempt_id=attempt_id: send_staff_push(attempt_id)
        )


def send_staff_push(attempt_id):
    attempt = (
        WhatsAppAttempt.objects.select_related(
            "staff__user", "order", "service_request"
        )
        .filter(pk=attempt_id, staff__active=True, staff__user__is_active=True)
        .first()
    )
    if attempt is None:
        return

    subscriptions = StaffPushSubscription.objects.filter(staff=attempt.staff)
    if not subscriptions.exists():
        return
    if not _vapid_is_configured():
        logger.warning(
            "Staff push is unavailable because VAPID settings are incomplete."
        )
        return

    if attempt.order_id:
        title = f"New {attempt.get_department_display()} order"
        body = "An order is waiting in your staff inbox."
    else:
        title = "New Services request"
        body = "A guest request is waiting in your staff inbox."
    payload = json.dumps(
        {
            "title": title,
            "body": body,
            "url": "/ordernotification",
            "tag": f"staff-notification-{attempt.pk}",
        }
    )
    try:
        private_key = base64.b64decode(
            settings.WEB_PUSH_VAPID_PRIVATE_KEY_B64, validate=True
        )
    except (ValueError, base64.binascii.Error):
        logger.error("Staff push is unavailable because the VAPID private key is invalid.")
        return
    for subscription in subscriptions:
        try:
            webpush(
                subscription_info={
                    "endpoint": subscription.endpoint,
                    "keys": {
                        "p256dh": subscription.p256dh,
                        "auth": subscription.auth,
                    },
                },
                data=payload,
                vapid_private_key=private_key,
                vapid_claims={"sub": settings.WEB_PUSH_VAPID_SUBJECT},
                timeout=8,
            )
        except WebPushException as error:
            response = getattr(error, "response", None)
            status_code = getattr(response, "status_code", None)
            if status_code in {404, 410}:
                subscription.delete()
                logger.info(
                    "Removed expired staff push subscription %s.",
                    subscription.pk,
                )
            else:
                logger.error(
                    "Staff push delivery failed for subscription %s (HTTP %s).",
                    subscription.pk,
                    status_code or "unknown",
                )
        except requests.RequestException:
            logger.exception(
                "Could not reach the push service for subscription %s.",
                subscription.pk,
            )
        except (VapidException, ValueError):
            logger.exception(
                "Could not create a push notification for subscription %s.",
                subscription.pk,
            )


def _vapid_is_configured():
    return all(
        (
            settings.WEB_PUSH_VAPID_PUBLIC_KEY,
            settings.WEB_PUSH_VAPID_PRIVATE_KEY_B64,
            settings.WEB_PUSH_VAPID_SUBJECT,
        )
    )
