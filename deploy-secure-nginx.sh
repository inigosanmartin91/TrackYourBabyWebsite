set -e

cp /etc/nginx/sites-available/trackyourbaby.app "/etc/nginx/sites-available/trackyourbaby.app.bak-$(date +%Y%m%d%H%M%S)"

cat > /etc/nginx/sites-available/trackyourbaby.app <<'NGINX'
server {
    listen 80;
    server_name trackyourbaby.app www.trackyourbaby.app;
    return 301 https://trackyourbaby.app$request_uri;
}

server {
    listen 443 ssl;
    server_name www.trackyourbaby.app;

    ssl_certificate /etc/letsencrypt/live/trackyourbaby.app/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/trackyourbaby.app/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    return 301 https://trackyourbaby.app$request_uri;
}

server {
    listen 443 ssl;
    server_name trackyourbaby.app;

    root /var/www/trackyourbaby.app;
    index index.html;

    ssl_certificate /etc/letsencrypt/live/trackyourbaby.app/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/trackyourbaby.app/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ /\. {
        deny all;
    }
}
NGINX

nginx -t
systemctl reload nginx
