# Haidware Hospitality Demo

A Flutter application demoing the Haidware hospitality ordering experience.

## Run locally

```sh
flutter pub get
flutter run
```

Run the widget tests and analyzer with:

```sh
flutter test
flutter analyze
```

## Deploy on Railway

The root-level `railway.json` selects the multi-stage `Dockerfile` builder,
builds the Flutter web release, and serves it with Nginx. The server listens on
Railway's injected `PORT`, supports Flutter web route fallbacks, and exposes
`/health` for Railway's health check.

Connect the GitHub repository to a Railway service with the service root
directory set to the repository root (the directory containing `railway.json`
and `Dockerfile`). Subsequent pushes to the connected branch trigger Railway
deployments.

## Install as a PWA

The Flutter web release includes the Haidware app manifest and install icons.
Deploy over HTTPS, then use the browser's install option (or Add to Home Screen
on mobile) to install Haidware.

## Payment confirmation demo

Checkout uses bank transfer and generates a reception payment-message preview
after staff select **I have paid**. Staff can review the message and select
**Confirm Order**. The preview is shown in the app only; no WhatsApp message is
sent.

## Admin portal and QR ordering

The Django admin portal is deployed in the same Railway service as this Flutter
app. The guest/device app remains at `/`, the admin dashboard is available at
`/admin`, and room/table QR codes open the browser ordering flow at
`/guest-order/`. Both ordering experiences use the portal's menu, device
sessions, payment settings, preparation estimates, and order API.

For local development, run the portal from `admin_portal`:

```powershell
cd admin_portal
python -m pip install -r requirements.txt
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```

The portal can be tested with:

```powershell
cd admin_portal
python manage.py check
python manage.py test
```

The Railway Docker build serves Flutter and Django from one origin. Its
`API_BASE_URL` build argument defaults to
`https://device-demo-production.up.railway.app`; set it to the public service
origin if the Railway domain changes. Configure these Railway variables:

- `SECRET_KEY`: a unique, randomly generated production secret.
- `DEBUG`: `0`.
- `ALLOWED_HOSTS`: the Railway hostname (and any custom domain), comma-separated.
- `CSRF_TRUSTED_ORIGINS`: the matching HTTPS origins.
- `DATABASE_URL`: the Supabase PostgreSQL URI from **Project Settings → Database
  → Connection string** (choose URI format). Do not use the project `https://…
  .supabase.co` API URL here. For Railway, use the Supabase connection option
  reachable from your network and require SSL (`sslmode=require`).
- `GUEST_ORDER_BASE_URL`: optional; otherwise QR codes use the public request URL.

The container runs migrations before starting and serves `/health` for Railway's
health check. After configuring Supabase PostgreSQL and deploying, create the
first admin user from the Railway service shell with
`python manage.py createsuperuser`.
Railway terminates HTTPS before requests reach the container, so
`SECURE_SSL_REDIRECT` defaults to `0`; the platform serves the public app over
HTTPS. Do not commit `.env` files or local SQLite databases. For cross-origin
external tablet deployments, add their origins to `CORS_ALLOWED_ORIGINS`.
