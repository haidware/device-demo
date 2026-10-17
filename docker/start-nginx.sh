#!/bin/sh
set -eu

: "${PORT:=8080}"
sed "s/\${PORT}/${PORT}/g" /etc/nginx/templates/default.conf.template \
  > /etc/nginx/conf.d/default.conf

exec nginx -g 'daemon off;'
