#!/bin/bash

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo or as root."
  exit 1
fi

echo "=========================================================="
echo "    Laravel GitHub Deploy Installer (LEMP + SSL)          "
echo "=========================================================="

# ---------------------------------------------------------------
# Parse CLI arguments
# Usage:
#   sudo bash laravel_deploy_github.sh \
#     --repo https://github.com/user/repo.git \
#     --branch main \
#     --project my-app \
#     --domain example.com \
#     --email admin@example.com \
#     --php 8.3
# ---------------------------------------------------------------
REPO_URL=""
BRANCH="main"
PROJECT_NAME=""
DOMAIN_NAME=""
SSL_EMAIL=""
PHP_VERSION=""

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --repo)     REPO_URL="$2";     shift ;;
    --branch)   BRANCH="$2";       shift ;;
    --project)  PROJECT_NAME="$2"; shift ;;
    --domain)   DOMAIN_NAME="$2";  shift ;;
    --email)    SSL_EMAIL="$2";    shift ;;
    --php)      PHP_VERSION="$2";  shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

# Fall back to interactive prompts for any missing values
[ -z "$REPO_URL" ]      && read -p "Enter GitHub Repo URL (e.g., https://github.com/user/repo.git): " REPO_URL
[ -z "$PROJECT_NAME" ]  && read -p "Enter Project Name (e.g., my-app): " PROJECT_NAME
[ -z "$DOMAIN_NAME" ]   && read -p "Enter Domain Name (e.g., example.com): " DOMAIN_NAME
[ -z "$SSL_EMAIL" ]     && read -p "Enter Email for SSL (e.g., admin@example.com): " SSL_EMAIL
[ -z "$PHP_VERSION" ]   && read -p "Enter PHP Version (e.g., 8.2, 8.3): " PHP_VERSION

# Derive DB credentials from project name
DB_PASSWORD=$(openssl rand -base64 12)
DB_NAME=$(echo "$PROJECT_NAME" | tr '-' '_')
DB_USER="${DB_NAME}_user"

echo "----------------------------------------------------------"
echo "Config Summary"
echo "----------------------------------------------------------"
echo "  Repo     : $REPO_URL  (branch: $BRANCH)"
echo "  Project  : $PROJECT_NAME"
echo "  Domain   : $DOMAIN_NAME"
echo "  PHP      : $PHP_VERSION"
echo "  DB Name  : $DB_NAME"
echo "  DB User  : $DB_USER"
echo "----------------------------------------------------------"
read -p "Continue? [y/N]: " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

echo "----------------------------------------------------------"
echo "Step 1: Adding PHP Repository and Updating System..."
echo "----------------------------------------------------------"
apt update && apt upgrade -y
apt install software-properties-common -y
add-apt-repository ppa:ondrej/php -y
apt update

echo "----------------------------------------------------------"
echo "Step 2: Installing Nginx, MySQL, PHP $PHP_VERSION and Git..."
echo "----------------------------------------------------------"
apt install nginx mysql-server certbot python3-certbot-nginx unzip curl git -y
apt install php$PHP_VERSION-fpm php$PHP_VERSION-mysql php$PHP_VERSION-mbstring \
            php$PHP_VERSION-xml php$PHP_VERSION-bcmath php$PHP_VERSION-curl \
            php$PHP_VERSION-zip php$PHP_VERSION-intl -y

echo "----------------------------------------------------------"
echo "Step 3: Installing Composer..."
echo "----------------------------------------------------------"
curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
rm /tmp/composer-setup.php

echo "----------------------------------------------------------"
echo "Step 4: Creating Database and User..."
echo "----------------------------------------------------------"
mysql -e "CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

echo "----------------------------------------------------------"
echo "Step 5: Setting Up SSH Deploy Key for GitHub..."
echo "----------------------------------------------------------"
SSH_DIR="/root/.ssh"
SSH_KEY="$SSH_DIR/github_deploy"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [ ! -f "$SSH_KEY" ]; then
  ssh-keygen -t ed25519 -C "deploy@$DOMAIN_NAME" -f "$SSH_KEY" -N ""
fi

# Trust github.com host
ssh-keyscan -t ed25519 github.com >> "$SSH_DIR/known_hosts" 2>/dev/null

# Configure SSH to use this key for github.com
if ! grep -q "Host github.com" "$SSH_DIR/config" 2>/dev/null; then
  cat <<EOF >> "$SSH_DIR/config"
Host github.com
    HostName github.com
    User git
    IdentityFile $SSH_KEY
    StrictHostKeyChecking no
EOF
fi

echo ""
echo "=========================================================="
echo " ACTION REQUIRED: Add this Deploy Key to your GitHub repo "
echo "=========================================================="
echo ""
cat "$SSH_KEY.pub"
echo ""
echo "Go to: GitHub repo → Settings → Deploy keys → Add deploy key"
echo "Paste the key above and click 'Add key' (read-only is enough)."
echo ""
read -p "Press ENTER once you have added the deploy key to GitHub..."

echo "----------------------------------------------------------"
echo "Step 6: Cloning Repository from GitHub..."
echo "----------------------------------------------------------"
DEPLOY_DIR="/var/www/$PROJECT_NAME"

if [ -d "$DEPLOY_DIR" ]; then
  echo "Directory $DEPLOY_DIR already exists. Pulling latest changes..."
  GIT_SSH_COMMAND="ssh -i $SSH_KEY" git -C "$DEPLOY_DIR" pull origin "$BRANCH"
else
  GIT_SSH_COMMAND="ssh -i $SSH_KEY" git clone --branch "$BRANCH" "$REPO_URL" "$DEPLOY_DIR"
fi

echo "----------------------------------------------------------"
echo "Step 7: Installing PHP Dependencies..."
echo "----------------------------------------------------------"
cd "$DEPLOY_DIR"
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader

echo "----------------------------------------------------------"
echo "Step 8: Configuring Laravel .env File..."
echo "----------------------------------------------------------"
if [ ! -f "$DEPLOY_DIR/.env" ]; then
  cp "$DEPLOY_DIR/.env.example" "$DEPLOY_DIR/.env"
fi

sed -i "s|^APP_URL=.*|APP_URL=https://$DOMAIN_NAME|" "$DEPLOY_DIR/.env"
sed -i "s|^DB_CONNECTION=.*|DB_CONNECTION=mysql|"    "$DEPLOY_DIR/.env"
sed -i "s|^# DB_HOST=.*|DB_HOST=127.0.0.1|"          "$DEPLOY_DIR/.env"
sed -i "s|^# DB_PORT=.*|DB_PORT=3306|"               "$DEPLOY_DIR/.env"
sed -i "s|^# DB_DATABASE=.*|DB_DATABASE=$DB_NAME|"   "$DEPLOY_DIR/.env"
sed -i "s|^# DB_USERNAME=.*|DB_USERNAME=$DB_USER|"   "$DEPLOY_DIR/.env"
sed -i "s|^# DB_PASSWORD=.*|DB_PASSWORD=$DB_PASSWORD|" "$DEPLOY_DIR/.env"

# Handle the case where DB_ lines are already uncommented
sed -i "s|^DB_DATABASE=.*|DB_DATABASE=$DB_NAME|"     "$DEPLOY_DIR/.env"
sed -i "s|^DB_USERNAME=.*|DB_USERNAME=$DB_USER|"     "$DEPLOY_DIR/.env"
sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=$DB_PASSWORD|" "$DEPLOY_DIR/.env"

echo "----------------------------------------------------------"
echo "Step 9: Setting Permissions..."
echo "----------------------------------------------------------"
mkdir -p "$DEPLOY_DIR/storage/framework/cache/data"
mkdir -p "$DEPLOY_DIR/storage/framework/sessions"
mkdir -p "$DEPLOY_DIR/storage/framework/testing"
mkdir -p "$DEPLOY_DIR/storage/framework/views"
mkdir -p "$DEPLOY_DIR/storage/logs"
mkdir -p "$DEPLOY_DIR/bootstrap/cache"
chown -R www-data:www-data "$DEPLOY_DIR"
chmod -R 775 "$DEPLOY_DIR/storage"
chmod -R 775 "$DEPLOY_DIR/bootstrap/cache"

echo "----------------------------------------------------------"
echo "Step 10: Generating App Key and Running Migrations..."
echo "----------------------------------------------------------"
sudo -u www-data php artisan key:generate
sudo -u www-data php artisan migrate --force
sudo -u www-data php artisan config:cache
sudo -u www-data php artisan route:cache
sudo -u www-data php artisan view:cache

echo "----------------------------------------------------------"
echo "Step 11: Configuring Nginx..."
echo "----------------------------------------------------------"
cat <<EOF > /etc/nginx/sites-available/$PROJECT_NAME
server {
    listen 80;
    server_name $DOMAIN_NAME;
    root $DEPLOY_DIR/public;

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

ln -sf /etc/nginx/sites-available/$PROJECT_NAME /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

echo "----------------------------------------------------------"
echo "Step 12: Installing SSL Certificate (Certbot)..."
echo "----------------------------------------------------------"
certbot --nginx -d "$DOMAIN_NAME" --non-interactive --agree-tos -m "$SSL_EMAIL"

echo "=========================================================="
echo "    DEPLOYMENT COMPLETE!                                  "
echo "=========================================================="
echo "URL          : https://$DOMAIN_NAME"
echo "Project Path : $DEPLOY_DIR"
echo "PHP Version  : $PHP_VERSION"
echo "Branch       : $BRANCH"
echo "Database     : $DB_NAME"
echo "DB User      : $DB_USER"
echo "DB Password  : $DB_PASSWORD"
echo "=========================================================="
echo "IMPORTANT: Save the DB password above in a secure place."
echo "=========================================================="
