#!/bin/bash

set -e -o pipefail

# Setup script for nextcloud using nginx, php-fpm and mysql in Vagrant

DATABASE_USER=nextcloud
DATABASE_NAME=nextcloud

NEXTCLOUD_VERSION=25.0.2
NEXTCLOUD_DOWNLOAD_URL=https://download.nextcloud.com/server/releases/nextcloud-$NEXTCLOUD_VERSION.tar.bz2
NEXTCLOUD_ADMIN_USER=nextadmin
NEXTCLOUD_ADMIN_PASSWD=nextadmin # sandbox only!
NEXTCLOUD_DATA_DIR=/opt/nextcloud/data

WORKSPACE_DIR=/workspace # vagrant shared folder
DOWNLOAD_CACHE_DIR=/workspace/.cache

# Hostname: needs to be set at provisioning time via cloudinit

# Local admin user
# Not here, since it depends on context (e.g. Vagrant already creates a vagrant specific user)
# For packer, etc. use a separate provisioning step

echo "[Upgrading system]"

# Chore: make sure we have the latest packages
apt update && apt -y dist-upgrade
apt -y install pwgen


echo "[Installing nginx]"

# Install & configure nginx
# Nginx master process is running as root, but workers seem to be running as `www-data`
apt -y install nginx
systemctl enable nginx

echo "[Installig mariadb-server]"

# Install & configure mysql, create database
apt -y install mariadb-server
systemctl enable mariadb

echo "[Installing PHP]"

apt -y install php7.4-fpm php-gd php-mysql php-curl php-mbstring php-intl php-gmp php-bcmath php-xml php-imagick php-zip
systemctl enable php7.4-fpm


echo "[Downloading and extracting nextcloud $NEXTCLOUD_VERSION]"

# Download & unpack nextcloud release
# Nextcloud downloads are slow as molasses, so we cache the download locally
if [[ ! -f $DOWNLOAD_CACHE_DIR/nextcloud-$NEXTCLOUD_VERSION.tar.bz2 ]]; then
    echo "Using cached copy"
    mkdir -p $DOWNLOAD_CACHE_DIR
    wget https://download.nextcloud.com/server/releases/nextcloud-$NEXTCLOUD_VERSION.tar.bz2 -P $DOWNLOAD_CACHE_DIR
    wget https://download.nextcloud.com/server/releases/nextcloud-$NEXTCLOUD_VERSION.tar.bz2.sha256 -P $DOWNLOAD_CACHE_DIR
    sha256sum -c $DOWNLOAD_CACHE_DIR/nextcloud-$NEXTCLOUD_VERSION.tar.bz2.sha256 < $DOWNLOAD_CACHE_DIR/nextcloud-$NEXTCLOUD_VERSION.tar.bz2
fi

tar -xjf $DOWNLOAD_CACHE_DIR/nextcloud-$NEXTCLOUD_VERSION.tar.bz2 -C /var/www

chown -R www-data:www-data /var/www/nextcloud

echo "[Setting up database]"

# Create database and application specific user
DATABASE_PASSWD=$(pwgen 20)
mysql -e"CREATE USER '$DATABASE_USER'@'localhost' IDENTIFIED BY '$DATABASE_PASSWD'"
mysql -e"CREATE DATABASE IF NOT EXISTS $DATABASE_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci"
mysql -e"GRANT ALL PRIVILEGES ON $DATABASE_NAME.* TO '$DATABASE_USER'@'localhost'"
mysql -e"FLUSH PRIVILEGES"

echo "[Generating self-signed key pair]"

# Generate a self-signed certificate since Nextcloud insists on SSL
openssl req -nodes -newkey rsa:2048 -keyout nextcloud.key -subj "/C=SG/ST=Singapore/L=Singapore/O=ACME Inc./OU=IT Department/CN=localhost" -out nextcloud.csr 
openssl x509 -signkey nextcloud.key -in nextcloud.csr -req -days 365 -out nextcloud.crt
mkdir -p /etc/ssl/nginx
cp nextcloud.key /etc/ssl/nginx/nextcloud.key
cp nextcloud.crt /etc/ssl/nginx/nextcloud.crt

echo "[Configuring nginx vhost]"

# Configure nginx vhost and disable default vhost
# See https://docs.nextcloud.com/server/latest/admin_manual/installation/nginx.html
cp /workspace/nginx.conf /etc/nginx/sites-available/nextcloud
unlink /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/nextcloud /etc/nginx/sites-enabled/nextcloud

# Test config
nginx -t

echo "[Installing and configuring nextcloud]"

# Install and configure nextcloud
mkdir -p $NEXTCLOUD_DATA_DIR
chown -R www-data:www-data $NEXTCLOUD_DATA_DIR

cd /var/www/nextcloud
sudo -u www-data php occ maintenance:install --database "mysql" \
    --database-name "$DATABASE_NAME" \
    --database-user "$DATABASE_USER" \
    --database-pass "$DATABASE_PASSWD" \
    --admin-user "$NEXTCLOUD_ADMIN_USER" \
    --admin-pass "$NEXTCLOUD_ADMIN_PASSWD" \
    --data-dir "$NEXTCLOUD_DATA_DIR"

echo "[Restarting Nginx]"

systemctl restart nginx

echo "[Setup complete]"
echo 
echo "Login URL: https://localhost:4443/"
echo "Admin username: $NEXTCLOUD_ADMIN_USER"
echo "Admin password: $NEXTCLOUD_ADMIN_PASSWD"
