from django.urls import path

from . import api

urlpatterns = [
    path("device/session/", api.device_session, name="api_device_session"),
    path("menu/", api.device_menu, name="api_device_menu"),
    path("menu/<int:item_id>/image/", api.menu_image, name="api_menu_image"),
    path("services/", api.device_services, name="api_device_services"),
    path("orders/", api.create_order, name="api_create_order"),
    path("orders/<str:order_number>/", api.order_status, name="api_order_status"),
    path("service-requests/", api.create_service_request, name="api_create_service_request"),
    path("staff/session/", api.staff_session, name="api_staff_session"),
    path("staff/notifications/", api.staff_notifications, name="api_staff_notifications"),
    path(
        "staff/push-subscriptions/",
        api.staff_push_subscription,
        name="api_staff_push_subscription",
    ),
]
