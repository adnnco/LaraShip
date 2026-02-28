#!/bin/bash

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo or as root."
  exit
fi

echo "=========================================================="
echo "    Automated LEMP, Laravel, MySQL & SSL Installer        "
echo "=========================================================="

# 1. Collect User Input
read -p "Enter Project Name (e.g., my-app): " PROJECT_NAME
read -p "Enter Domain Name (e.g., example.com): " DOMAIN_NAME
read -p "Enter Email for SSL (e.g., admin@example.com): " SSL_EMAIL
read -p "Enter PHP Version (e.g., 8.2, 8.3+): " PHP_VERSION

# Generate a random password for the new MySQL user
DB_PASSWORD=$(openssl rand -base64 12)
DB_NAME=$(echo $PROJECT_NAME | tr '-' '_')
DB_USER="${DB_NAME}_user"

echo "----------------------------------------------------------"
echo "Step 1: Adding PHP Repository and Updating System..."
echo "----------------------------------------------------------"
apt update && apt upgrade -y
apt install software-properties-common -y
add-apt-repository ppa:ondrej/php -y
apt update

echo "----------------------------------------------------------"
echo "Step 2: Installing Nginx, MySQL and PHP $PHP_VERSION..."
echo "----------------------------------------------------------"
apt install nginx mysql-server certbot python3-certbot-nginx unzip curl -y
apt install php$PHP_VERSION-fpm php$PHP_VERSION-mysql php$PHP_VERSION-mbstring \
            php$PHP_VERSION-xml php$PHP_VERSION-bcmath php$PHP_VERSION-curl \
            php$PHP_VERSION-zip php$PHP_VERSION-intl -y

echo "----------------------------------------------------------"
echo "Step 3: Installing Composer..."
echo "----------------------------------------------------------"
curl -sS https://getcomposer.org/installer -o composer-setup.php
php composer-setup.php --install-dir=/usr/local/bin --filename=composer
rm composer-setup.php

echo "----------------------------------------------------------"
echo "Step 4: Creating Database and User..."
echo "----------------------------------------------------------"
mysql -e "CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

echo "----------------------------------------------------------"
echo "Step 5: Creating Laravel Project..."
echo "----------------------------------------------------------"
cd /var/www
COMPOSER_ALLOW_SUPERUSER=1 composer create-project --prefer-dist laravel/laravel $PROJECT_NAME

echo "----------------------------------------------------------"
echo "Step 6: Configuring Laravel .env File..."
echo "----------------------------------------------------------"
cd /var/www/$PROJECT_NAME
sed -i "s/DB_CONNECTION=sqlite/DB_CONNECTION=mysql/" .env
sed -i "s/# DB_DATABASE=laravel/DB_DATABASE=$DB_NAME/" .env
sed -i "s/# DB_USERNAME=root/DB_USERNAME=$DB_USER/" .env
sed -i "s/# DB_PASSWORD=/DB_PASSWORD=$DB_PASSWORD/" .env

echo "----------------------------------------------------------"
echo "Step 7: Setting Permissions..."
echo "----------------------------------------------------------"
chown -R www-data:www-data /var/www/$PROJECT_NAME
chmod -R 775 /var/www/$PROJECT_NAME/storage
chmod -R 775 /var/www/$PROJECT_NAME/bootstrap/cache

echo "----------------------------------------------------------"
echo "Step 8: Configuring Nginx..."
echo "----------------------------------------------------------"
cat <<EOF > /etc/nginx/sites-available/$PROJECT_NAME
server {
    listen 80;
    server_name $DOMAIN_NAME;
    root /var/www/$PROJECT_NAME/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";

    index index.php;
    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF

ln -s /etc/nginx/sites-available/$PROJECT_NAME /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx

echo "----------------------------------------------------------"
echo "Step 9: Installing SSL Certificate (Certbot)..."
echo "----------------------------------------------------------"
# Note: Ensure DNS is pointed to this server before running
certbot --nginx -d $DOMAIN_NAME --non-interactive --agree-tos -m $SSL_EMAIL

echo "=========================================================="
echo "    INSTALLATION COMPLETE! 🎉                             "
echo "=========================================================="
echo "URL: https://$DOMAIN_NAME"
echo "Project Path: /var/www/$PROJECT_NAME"
echo "PHP Version: $PHP_VERSION"
echo "Database Name: $DB_NAME"
echo "Database User: $DB_USER"
echo "Database Pass: $DB_PASSWORD"
echo "=========================================================="
