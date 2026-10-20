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

## Payment confirmation

Checkout uses bank transfer and generates a reception payment-message preview
after guests enter the name on the bank sender account and select **I have
paid**. Selecting **Confirm Order** records the order and department-specific
payment notifications for both QR and device orders. The admin dashboard
updates its activity feed every eight seconds and shows the sender name, room,
department, and items. An authorized portal operator can open a prefilled
WhatsApp link to the currently assigned kitchen/bar staff number and tap
**Send**. WhatsApp is not sent automatically; real automated delivery needs an
official WhatsApp provider and its credentials/templates.

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

Managers/directors can create the first portal login at
`/admin/manager-signup/`. Manager signup is open to the public as requested;
anyone who reaches that page can register with manager-level access. A manager
can create administrator and staff logins from **Staff**. Administrators can
manage kitchen/bar menus, services, devices, rooms, QR codes, and staff, but
only managers can edit bank payout details in **Settings**. These are portal
roles; no Django superuser is needed for day-to-day portal access.

Menu photos are uploaded from a phone camera or image picker to Supabase
Storage. Create a **public** bucket named `menu-images` (or set
`SUPABASE_STORAGE_BUCKET` to the bucket name) and configure these Railway
variables:

- `SUPABASE_URL`: the project URL, for example `https://<project-ref>.supabase.co`.
- `SUPABASE_SERVICE_ROLE_KEY`: the private service-role key. Keep it only in
  Railway/local environment variables; never expose or commit it.
- `SUPABASE_STORAGE_BUCKET`: optional; defaults to `menu-images`.

The bucket must allow public reads so guest menus and the Flutter device can
display photos. Image writes are performed by Django using the private server
key. Accepted image formats are JPEG, PNG, and WebP, up to 5 MB each.

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
- `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `SUPABASE_STORAGE_BUCKET`:
  configure Supabase Storage for persistent menu photos.

The container runs migrations before starting and serves `/health` for Railway's
health check. After deploying, use `/admin/manager-signup/` to create the first
portal manager, then create an administrator account from **Staff**.
Railway terminates HTTPS before requests reach the container, so
`SECURE_SSL_REDIRECT` defaults to `0`; the platform serves the public app over
HTTPS. Do not commit `.env` files or local SQLite databases. For cross-origin
external tablet deployments, add their origins to `CORS_ALLOWED_ORIGINS`.
