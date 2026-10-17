FROM ghcr.io/cirruslabs/flutter:3.35.1 AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get --enforce-lockfile

COPY lib ./lib
COPY web ./web
RUN flutter build web --release --no-pub

FROM nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html
COPY docker/default.conf.template /etc/nginx/templates/default.conf.template
COPY docker/start-nginx.sh /usr/local/bin/start-nginx

RUN chmod +x /usr/local/bin/start-nginx

EXPOSE 8080
CMD ["/usr/local/bin/start-nginx"]
