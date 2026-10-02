#!/usr/bin/env bash
# Run on the existing VPS as root, from an uploaded Website directory.
# Does not overwrite the old TrackYourBaby site or its Nginx configuration.
set -euo pipefail
primary=${1:-lotoki.app}
case "$primary" in lotoki.app|lotoki.com|lotoki.es) ;; *) echo 'Choose lotoki.app, lotoki.com or lotoki.es'; exit 1;; esac
[[ $EUID == 0 ]] || { echo 'Run as root on the VPS'; exit 1; }
command -v nginx >/dev/null
command -v certbot >/dev/null
source_dir=$(cd "$(dirname "$0")/.." && pwd)
release_id=$(date -u +%Y%m%dT%H%M%SZ)
backup=/var/backups/lotoki/$release_id
release=/var/www/lotoki/releases/$release_id
mkdir -p "$backup" "$release" /var/www/lotoki/challenges
# Back up configuration and the OLD published site before deployment.
tar -czf "$backup/nginx.tar.gz" -C /etc nginx
if [[ -d /var/www/trackyourbaby.app ]]; then
  tar -czf "$backup/trackyourbaby-site.tar.gz" -C /var/www trackyourbaby.app
fi
if [[ -e /var/www/lotoki/current ]]; then
  readlink -f /var/www/lotoki/current > "$backup/previous-release.txt"
fi
for file in index.html styles.css; do cp "$source_dir/$file" "$release/"; done
for directory in es privacy-policy support assets; do cp -a "$source_dir/$directory" "$release/"; done
for file in robots.txt sitemap.xml; do
  if [[ -f "$source_dir/$file" ]]; then cp "$source_dir/$file" "$release/"; fi
done
# Keep the canonical host consistent with the selected primary.
python3 - "$release" "$primary" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1]);domain=sys.argv[2]
for path in [*root.rglob('*.html'),*root.glob('*.xml'),root/'robots.txt']:
    if path.exists():
        path.write_text(path.read_text().replace('https://lotoki.app','https://'+domain))
PY
find "$release" -type d -exec chmod 755 {} +
find "$release" -type f -exec chmod 644 {} +
cat > /etc/nginx/sites-available/lotoki <<'NGINX'
server {
    listen 80;
    server_name lotoki.app www.lotoki.app lotoki.com www.lotoki.com lotoki.es www.lotoki.es;
    location ^~ /.well-known/acme-challenge/ { root /var/www/lotoki/challenges; }
    location / { return 503; }
}
NGINX
ln -sfn /etc/nginx/sites-available/lotoki /etc/nginx/sites-enabled/lotoki
nginx -t
systemctl reload nginx
printf 'Prepared release: %s\nBackup: %s\n' "$release" "$backup"
printf 'Next: point all three A records to 82.112.254.215 and www CNAME to each domain.\n'
printf 'Then run: bash ops/activate-lotoki.sh %s %s\n' "$primary" "$release_id"
