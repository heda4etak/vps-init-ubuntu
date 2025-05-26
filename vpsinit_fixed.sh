#!/bin/bash

# === Ввод данных ===
read -p "Введите поддомен (например, ge.mydomain.com): " DOMAIN
read -p "Введите ваш email для Let's Encrypt: " EMAIL
read -p "Введите ваш Cloudflare API Token: " CF_TOKEN

# === Установка последней версии Nginx из официального репозитория ===
apt update && apt install -y curl gnupg2 ca-certificates lsb-release

# Удаление старой версии nginx, если есть
apt remove -y nginx nginx-common nginx-core || true

# Добавление репозитория nginx.org
curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
    | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null

echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" \
    | tee /etc/apt/sources.list.d/nginx.list >/dev/null

# Установка последней версии nginx
apt update && apt install -y nginx

# === Установка certbot и плагина Cloudflare ===
apt install -y certbot python3-certbot-dns-cloudflare

# === Создание директории для ключа Cloudflare ===
mkdir -p /root/.secrets
CRED_FILE="/root/.secrets/cloudflare.ini"

# === Запись API токена ===
echo "dns_cloudflare_api_token = $CF_TOKEN" > $CRED_FILE
chmod 600 $CRED_FILE

# === Получение сертификата ===
certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials "$CRED_FILE" \
  --non-interactive \
  --agree-tos \
  --email "$EMAIL" \
  -d "$DOMAIN"

# === Настройка Nginx ===
mkdir -p /var/www/$DOMAIN
echo "<h1>Welcome to $DOMAIN</h1>" > /var/www/$DOMAIN/index.html

NGINX_CONF="/etc/nginx/conf.d/$DOMAIN.conf"

cat > $NGINX_CONF <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    root /var/www/$DOMAIN;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

# === Проверка и перезапуск Nginx ===
nginx -t && systemctl reload nginx

# === Настройка автопродления ===
(crontab -l 2>/dev/null ; echo "0 2 * * * certbot renew --quiet && systemctl reload nginx") | crontab -

echo "✅ Готово! Сайт доступен по https://$DOMAIN"
