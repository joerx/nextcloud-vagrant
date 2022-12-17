#!/bin/bash

set -e -o pipefail

# Setup script for nextcloud using nginx, php-fpm and mysql in Vagrant

DATABASE_USER=nextcloud
DATABASE_NAME=nextcloud

NEXTCLOUD_VERSION=25.0.2
NEXTCLOUD_ADMIN_USER=nextadmin
NEXTCLOUD_ADMIN_PASSWD=nextadmin # sandbox only!
NEXTCLOUD_DATA_DIR=/opt/nextcloud/data

# Hostname: needs to be set at provisioning time via cloudinit

# Local admin user
# Not here, since it depends on context (e.g. Vagrant already creates a vagrant specific user)
# For packer, etc. use a separate provisioning step

# Chore: make sure we have the latest packages
apt update && apt -y dist-upgrade
apt -y install pwgen

# Install & configure nginx
# Nginx master process is running as root, but workers seem to be running as `www-data`
apt -y install nginx
systemctl enable nginx

# Install & configure mysql, create database
apt -y install mariadb-server
systemctl enable mariadb

apt -y install php7.4-fpm php-gd php-mysql php-curl php-mbstring php-intl php-gmp php-bcmath php-xml php-imagick php-zip
systemctl enable php7.4-fpm

# Download & unpack nextcloud release
wget https://download.nextcloud.com/server/releases/nextcloud-$NEXTCLOUD_VERSION.tar.bz2
wget https://download.nextcloud.com/server/releases/nextcloud-$NEXTCLOUD_VERSION.tar.bz2.sha256
sha256sum -c nextcloud-$NEXTCLOUD_VERSION.tar.bz2.sha256 < nextcloud-$NEXTCLOUD_VERSION.tar.bz2

tar -xjf nextcloud-$NEXTCLOUD_VERSION.tar.bz2 -C /var/www
chown -R www-data:www-data /var/www/nextcloud

# Create database and application specific user
DATABASE_PASSWD=$(pwgen 20)
mysql -e"CREATE USER '$DATABASE_USER'@'localhost' IDENTIFIED BY '$DATABASE_PASSWD'"
mysql -e"CREATE DATABASE IF NOT EXISTS $DATABASE_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci"
mysql -e"GRANT ALL PRIVILEGES ON $DATABASE_NAME.* TO '$DATABASE_USER'@'localhost'"
mysql -e"FLUSH PRIVILEGES"

# Generate a self-signed certificate since Nextcloud insists on SSL
openssl req -nodes -newkey rsa:2048 -keyout nextcloud.key -subj "/C=SG/ST=Singapore/L=Singapore/O=ACME Inc./OU=IT Department/CN=localhost" -x509 nextcloud.crt -days 356 -out nextcloud.pem 
openssl x509 -signkey nextcloud.key -in nextcloud.csr -req -days 365 -out nextcloud.crt
mkdir -p /etc/ssl/nginx
cp nextcloud.key /etc/ssl/nginx/nextcloud.key
cp nextcloud.crt /etc/ssl/nginx/nextcloud.crt

# Configure nginx vhost and disable default vhost
# See https://docs.nextcloud.com/server/latest/admin_manual/installation/nginx.html
cp /workspace/nginx.conf /etc/nginx/sites-available/nextcloud
unlink /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/nextcloud /etc/nginx/sites-enabled/nextcloud

# Test config
nginx -t

# Install and configure nextcloud
mkdir -p $NEXTCLOUD_DATA_DIR
mv /var/www/nextcloud/data/* $NEXTCLOUD_DATA_DIR
chown -R www-data:www-data $NEXTCLOUD_DATA_DIR

cd /var/www/nextcloud
sudo -u www-data php occ maintenance:install --database "mysql" \
    --database-name "$DATABASE_NAME" \
    --database-user "$DATABASE_USER" \
    --database-pass "$DATABASE_PASSWD" \
    --admin-user "$NEXTCLOUD_ADMIN_USER" \
    --admin-pass "$NEXTCLOUD_ADMIN_PASSWD"

sudo -u www-data php occ config:system:set trusted_domains 1 --value=*
sudo -u www-data php occ config:system:set datadirectory --value=$NEXTCLOUD_DATA_DIR

systemctl restart nginx
