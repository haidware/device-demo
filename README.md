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

The repository includes a multi-stage `Dockerfile`. Railway detects it on the
project's root branch, builds the Flutter web release, and serves it with Nginx.
The server listens on Railway's injected `PORT`, supports Flutter web route
fallbacks, and exposes `/health`.

Connect the GitHub repository to a Railway service with the service root
directory set to the repository root. Subsequent pushes to the connected branch
trigger Railway deployments.

## Install as a PWA

The Flutter web release includes the Haidware app manifest and install icons.
Deploy over HTTPS, then use the browser's install option (or Add to Home Screen
on mobile) to install Haidware.
