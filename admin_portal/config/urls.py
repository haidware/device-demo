from django.contrib import admin
from django.contrib.auth import views as auth_views
from django.urls import include, path, re_path
from django.views.generic import RedirectView

from portal import views
from portal.views import health
from .web import flutter_home

urlpatterns = [
    path("", flutter_home, name="flutter_home"),
    path("health/", health, name="health"),
    path("health", health),
    re_path(
        r"^admin/?$",
        RedirectView.as_view(pattern_name="dashboard", permanent=False),
    ),
    path(
        "admin/login/",
        auth_views.LoginView.as_view(template_name="login.html"),
        name="login",
    ),
    path("admin/manager-signup/", views.manager_signup, name="manager_signup"),
    path("admin/logout/", auth_views.LogoutView.as_view(), name="logout"),
    path("django-admin/", admin.site.urls),
    re_path(r"^commandcenter/?$", views.command_center, name="command_center"),
    path(
        "commandcenter/<int:property_id>/action/",
        views.command_center_action,
        name="command_center_action",
    ),
    path("api/v1/", include("portal.api_urls")),
    path("guest-order/", views.guest_order, name="guest_order"),
    path("admin/", include("portal.urls")),
    re_path(
        r"^(?!admin(?:/|$)|django-admin(?:/|$)|commandcenter(?:/|$)|api(?:/|$)|guest-order(?:/|$)|health/?$|static(?:/|$)).+$",
        flutter_home,
    ),
]
