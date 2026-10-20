from django.urls import path

from . import views

urlpatterns = [
    path("dashboard/", views.dashboard, name="dashboard"),
    path("orders/", views.order_list, name="orders"),
    path("orders/<int:order_id>/", views.order_detail, name="order_detail"),
    path("orders/<int:order_id>/update/", views.update_order, name="update_order"),
    path("service-requests/", views.service_request_list, name="service_requests"),
    path(
        "service-requests/<int:request_id>/update/",
        views.update_service_request,
        name="update_service_request",
    ),
    path("payments/", views.payment_list, name="payments"),
    path("handler/", views.handler_view, name="handler"),
    path("menu/add/", views.menu_create, name="menu_add"),
    path("menu/<str:department>/", views.menu_list, name="menu_list"),
    path("menu/<int:item_id>/edit/", views.menu_edit, name="menu_edit"),
    path("services/", views.services_list, name="services"),
    path("services/<int:service_id>/toggle/", views.service_toggle, name="service_toggle"),
    path("rooms/", views.room_list, name="rooms"),
    path("rooms/add/", views.room_create, name="room_add"),
    path("rooms/<int:room_id>/edit/", views.room_edit, name="room_edit"),
    path("rooms/<int:room_id>/qr/", views.room_qr, name="room_qr"),
    path("rooms/<int:room_id>/qr/image/", views.room_qr_image, name="room_qr_image"),
    path("devices/", views.device_list, name="devices"),
    path("devices/add/", views.device_create, name="device_add"),
    path("devices/<int:device_id>/edit/", views.device_edit, name="device_edit"),
    path("staff/", views.staff_list, name="staff"),
    path("staff/add/", views.staff_create, name="staff_add"),
    path("staff/<int:user_id>/toggle/", views.staff_toggle, name="staff_toggle"),
    path("staff-shifts/", views.staff_shifts, name="staff_shifts"),
    path("reports/", views.reports, name="reports"),
    path("settings/", views.settings_page, name="settings"),
]
