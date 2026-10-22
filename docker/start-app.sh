#!/bin/sh
set -eu

python manage.py migrate --noinput
python manage.py bootstrap_command_center
exec gunicorn config.wsgi:application \
  --bind "0.0.0.0:${PORT:-8080}" \
  --workers "${WEB_CONCURRENCY:-2}" \
  --access-logfile -
