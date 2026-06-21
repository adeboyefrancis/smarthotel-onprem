#!/bin/bash
set -e

WEB1_IP="$1"
WEB2_IP="$2"

echo "=== UbuntuWAF Setup starting ==="
echo "Upstream web servers: $WEB1_IP, $WEB2_IP"

apt-get update -y
apt-get install -y nginx

cat > /etc/nginx/sites-available/smarthotel <<EOF
upstream smarthotel_backend {
    server ${WEB1_IP}:80;
    server ${WEB2_IP}:80;
}

server {
    listen 80 default_server;
    server_name _;

    # --- basic WAF-style hardening rules ---
    server_tokens off;
    client_max_body_size 2M;

    # Block a handful of common scanner/bot user agents
    if (\$http_user_agent ~* (nikto|sqlmap|nessus|fuzz|acunetix)) {
        return 403;
    }

    # Block obvious SQLi / path traversal attempts in the query string
    if (\$query_string ~* "(union.*select|drop\s+table|\.\./\.\./)") {
        return 403;
    }

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    location / {
        proxy_pass http://smarthotel_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/smarthotel /etc/nginx/sites-enabled/smarthotel

nginx -t
systemctl restart nginx
systemctl enable nginx

echo "=== UbuntuWAF Setup complete — proxying / load-balancing across Web1 + Web2 ==="
