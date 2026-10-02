#!/usr/bin/env bash
# Activate only after DNS resolves to this VPS. Leave the old website intact.
set -euo pipefail
primary=${1:?Primary domain required}
release_id=${2:?Release ID required}
case "$primary" in lotoki.app|lotoki.com|lotoki.es) ;; *) exit 1;; esac
[[ $release_id =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || exit 1
[[ $EUID == 0 ]] || exit 1
release=/var/www/lotoki/releases/$release_id
[[ -f "$release/index.html" ]] || exit 1
for domain in lotoki.app www.lotoki.app lotoki.com www.lotoki.com lotoki.es www.lotoki.es; do
  actual=$(getent ahostsv4 "$domain" | awk '{print $1}' | sort -u)
  [[ "$actual" == '82.112.254.215' ]] || { echo "DNS is not ready for $domain: $actual"; exit 1; }
done
# Reuse the existing Certbot account; do not sign up for a new service/account.
certbot certonly --webroot -w /var/www/lotoki/challenges --cert-name lotoki \
  -d lotoki.app -d www.lotoki.app -d lotoki.com -d www.lotoki.com -d lotoki.es -d www.lotoki.es --non-interactive
config=$(mktemp)
trap 'rm -f "$config"' EXIT
cat > "$config" <<NGINX
server {
    listen 80;
    server_name lotoki.app www.lotoki.app lotoki.com www.lotoki.com lotoki.es www.lotoki.es;
    location ^~ /.well-known/acme-challenge/ { root /var/www/lotoki/challenges; }
    location / { return 301 https://$primary\$request_uri; }
}
server {
    listen 443 ssl;
    server_name $primary;
    root /var/www/lotoki/current;
    index index.html;
    ssl_certificate /etc/letsencrypt/live/lotoki/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/lotoki/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    location / { try_files \$uri \$uri/ =404; }
    location ~ /\. { deny all; }
}
NGINX
aliases=''
for domain in lotoki.app www.lotoki.app lotoki.com www.lotoki.com lotoki.es www.lotoki.es; do
  if [[ "$domain" != "$primary" ]]; then aliases="$aliases $domain"; fi
done
cat >> "$config" <<NGINX
server {
    listen 443 ssl;
    server_name $aliases;
    ssl_certificate /etc/letsencrypt/live/lotoki/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/lotoki/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    return 301 https://$primary\$request_uri;
}
NGINX
cp /etc/nginx/sites-available/lotoki /var/backups/lotoki/$release_id/lotoki-before-activation.conf
cp "$config" /etc/nginx/sites-available/lotoki
if ! nginx -t; then
  cp /var/backups/lotoki/$release_id/lotoki-before-activation.conf /etc/nginx/sites-available/lotoki
  exit 1
fi
ln -sfn "$release" /var/www/lotoki/current.next
mv -Tf /var/www/lotoki/current.next /var/www/lotoki/current
systemctl reload nginx
curl --fail --silent --show-error --resolve "$primary:443:127.0.0.1" "https://$primary/" >/dev/null
printf 'Lotoki is active on https://%s. Old TrackYourBaby site preserved.\n' "$primary"
