#!/bin/sh

mkdir -p /etc/nginx/ssl

# Generate self-signed cert & key
yes ff | openssl req -x509 -nodes -days 3650 \
    -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/nginx-selfsigned.key \
    -out /etc/nginx/ssl/nginx-selfsigned.crt \
    &>/dev/null

# Create self-signed cert include
cat <<EOF > /etc/nginx/ssl/self-signed.conf
ssl_certificate /etc/nginx/ssl/nginx-selfsigned.crt;
ssl_certificate_key /etc/nginx/ssl/nginx-selfsigned.key;
EOF

# Create SSL params (ECDHE-only, no DH param)
cat <<EOF > /etc/nginx/ssl/ssl-params.conf
ssl_protocols TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
ssl_ecdh_curve secp384r1; # ECDHE curve, very secure and fast

ssl_session_timeout  10m;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;

resolver 80.80.80.80 80.80.81.81 valid=300s;
resolver_timeout 5s;

add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
EOF
