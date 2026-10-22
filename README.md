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

## Deploy on Render

The root-level `Dockerfile` builds the Flutter web release and serves it from
the Django portal. The server listens on Render's injected `PORT`, supports
Flutter web route fallbacks, and exposes `/health` for Render's health check.

Connect the GitHub repository to a Render **Web Service**, select **Docker** as
the runtime, and leave the root directory at the repository root (the directory
containing `Dockerfile`). Set the health check path to `/health`. Deployments
use Render's injected `PORT`; set `API_BASE_URL` as a Docker build argument only
if the public app domain changes.

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

The Django admin portal is deployed in the same Render service as this Flutter
app. The guest/device app remains at `/`, the admin dashboard is available at
`/admin`, and room/table QR codes open the ordering homepage at `/?device_id=…`.
Scanning a QR starts the same homepage flow as a device, with the room ID
preselected and no manual device-ID entry. Both ordering experiences use the portal's menu, device
sessions, payment settings, preparation estimates, and order API.
Register devices from **Devices** to generate a device ID and enter its room or
table number; an existing location is reused if the number is already set up.
The separate **Rooms & Tables QR** flow is for creating locations and QR codes
for QR-only guest access.

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
provides the hotel/lounge name and location during signup; these property
details are saved in `PortalSettings` and returned to registered devices by the
device session API. A manager can create the administrator login and edit
property and bank details in **Settings**. Administrators manage kitchen/bar
menus, services, devices, rooms, QR codes, staff, and orders. These are portal
roles; no Django superuser is needed for day-to-day portal access.

Platform superusers can open `/commandcenter` to review properties and manager
contact details, confirm or reset subscription status, and deactivate or
reactivate accounts. Every property receives a stable `HDW-` ID. Deactivation
retains all property and activity records while blocking staff portal access
and device API requests; it does not permanently erase data.
Create a separate platform-operator login with `python manage.py createsuperuser`
against the deployed database. Do not grant Django superuser privileges to
hotel or lounge managers.

Each manager signup creates a separate property record in the shared database.
Rooms, devices, menu items, services, staff, orders, requests, shift
assignments, and notification activity are scoped to that property. Device APIs
derive the property from the registered device ID; they do not accept a
client-supplied property identifier. Existing records are assigned to the
pre-existing property when the tenant-isolation migration runs.

Menu photos are uploaded from a phone camera or image picker to Supabase
Storage. Create a **public** bucket named `menu-images` (or set
`SUPABASE_STORAGE_BUCKET` to the bucket name) and configure these Render
variables:

- `SUPABASE_URL`: the project URL, for example `https://<project-ref>.supabase.co`.
- `SUPABASE_SERVICE_ROLE_KEY`: the private service-role key. Keep it only in
  Railway/local environment variables; never expose or commit it.
- `SUPABASE_STORAGE_BUCKET`: optional; defaults to `menu-images`.

The bucket must allow public reads so guest menus and the Flutter device can
display photos. Image writes are performed by Django using the private server
key. Accepted image formats are JPEG, PNG, and WebP, up to 5 MB each.

Application tables in Supabase's `public` schema are not intended for direct
client access. Migration `0010` revokes schema, table, and sequence privileges
from `PUBLIC`, `anon`, and `authenticated`, enables row-level security without
client policies, and applies the privilege restrictions to tables created
later by the migration role. Django continues to access the database through
`DATABASE_URL` as the backend database owner; do not use an `anon` or
`authenticated` connection for Django. The migration requires Supabase's
`anon` and `authenticated` roles and does not change Supabase Storage bucket
permissions. After deploying, verify the migration completed before treating
the tables as restricted.

The Render Docker build serves Flutter and Django from one origin. Its
`API_BASE_URL` build argument defaults to
`https://device-demo.onrender.com`; set it to the public service origin if the
Render domain changes. Configure these Render environment variables:

- `SECRET_KEY`: a unique, randomly generated production secret.
- `DEBUG`: `0`.
- `ALLOWED_HOSTS`: `device-demo.onrender.com` (and any custom domain),
  comma-separated.
- `CSRF_TRUSTED_ORIGINS`: the matching HTTPS origins.
- `DATABASE_URL`: the Supabase PostgreSQL URI from **Project Settings → Database
  → Connection string** (choose URI format). Do not use the project `https://…
  .supabase.co` API URL here. For Railway, use the Supabase connection option
  reachable from your network and require SSL (`sslmode=require`).
- `GUEST_ORDER_BASE_URL`: optional; otherwise QR codes use the public request URL.
- `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `SUPABASE_STORAGE_BUCKET`:
  configure Supabase Storage for persistent menu photos.

The container runs migrations before starting and serves `/health` for Render's
health check. After deploying, use `/admin/manager-signup/` to create the first
portal manager, then create an administrator account from **Staff**.
Render terminates HTTPS before requests reach the container, so
`SECURE_SSL_REDIRECT` defaults to `0`; the platform serves the public app over
HTTPS. Do not commit `.env` files or local SQLite databases. For cross-origin
external tablet deployments, add their origins to `CORS_ALLOWED_ORIGINS`.
