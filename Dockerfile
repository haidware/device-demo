FROM ghcr.io/cirruslabs/flutter:3.35.1 AS flutter-build

WORKDIR /app
ARG API_BASE_URL=https://device-demo.onrender.com

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get --enforce-lockfile

COPY lib ./lib
COPY web ./web
RUN flutter build web --release --no-pub --dart-define=API_BASE_URL=${API_BASE_URL}

FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBUG=0 \
    ALLOWED_HOSTS=device-demo.onrender.com,device-demo-production.up.railway.app \
    CSRF_TRUSTED_ORIGINS=https://device-demo.onrender.com,https://device-demo-production.up.railway.app \
    SECURE_SSL_REDIRECT=0

WORKDIR /app/admin_portal

COPY admin_portal/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY admin_portal/ ./
COPY --from=flutter-build /app/build/web ./web_build/

RUN DEBUG=1 python manage.py collectstatic --noinput

COPY docker/start-app.sh /usr/local/bin/start-app
RUN chmod +x /usr/local/bin/start-app

EXPOSE 8080
CMD ["/usr/local/bin/start-app"]
