#! /usr/bin/env bash

# Variables
APPENV=local
DBHOST=localhost
DBNAME=t3_62
DBUSER=dbuser1
DBPASSWD=supersecret
TYPO3VER=6.2.29
LOCALDOMAIN=6.2.local.dev

echo -e "\n--- Mkay, installing now... ---\n"

echo -e "\n--- Updating packages list ---\n"
apt-get -qq update

echo -e "\n--- Install base packages ---\n"
apt-get -y install vim curl build-essential python-software-properties git > /dev/null 2>&1

echo -e "\n--- Add some repos to update our distro ---\n"
add-apt-repository ppa:ondrej/php5 > /dev/null 2>&1
add-apt-repository ppa:chris-lea/node.js > /dev/null 2>&1

echo -e "\n--- Updating packages list ---\n"
apt-get -qq update

echo -e "\n--- Install MySQL specific packages and settings ---\n"
echo "mysql-server mysql-server/root_password password $DBPASSWD" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $DBPASSWD" | debconf-set-selections
echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
echo "phpmyadmin phpmyadmin/app-password-confirm password $DBPASSWD" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/admin-pass password $DBPASSWD" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/app-pass password $DBPASSWD" | debconf-set-selections
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect none" | debconf-set-selections
apt-get -y install mysql-server-5.5 phpmyadmin > /dev/null 2>&1

echo -e "\n--- Setting up our MySQL user and db ---\n"
mysql -uroot -p$DBPASSWD -e "CREATE DATABASE $DBNAME"
mysql -uroot -p$DBPASSWD -e "grant all privileges on $DBNAME.* to '$DBUSER'@'localhost' identified by '$DBPASSWD'"

echo -e "\n--- Installing PHP-specific packages ---\n"
apt-get -y install php5 apache2 libapache2-mod-php5 php5-curl php5-gd php5-mcrypt php5-mysql php-apc > /dev/null 2>&1
echo -e "\n--- Installing GraphicMagick---\n"
apt-get -y install graphicsmagick

echo -e "\n--- Enabling mod-rewrite ---\n"
a2enmod rewrite > /dev/null 2>&1

echo -e "\n--- Allowing Apache override to all ---\n"
sed -i "s/AllowOverride None/AllowOverride All/g" /etc/apache2/apache2.conf

echo -e "\n--- Setting document root ---\n"
rm -rf /var/www/html
mkdir /var/www/html
chown -R www-data:www-data /var/www/html
usermod -aG www-data vagrant
echo -e "\n--- We definitly need to see the PHP errors, turning them on ---\n"
sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php5/apache2/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php5/apache2/php.ini

echo -e "\n--- Turn off disabled pcntl functions so we can use Boris ---\n"
sed -i "s/disable_functions = .*//" /etc/php5/cli/php.ini

echo -e "\n--- Setting up memory_limit to 240M ---\n"
sed -i "s/memory_limit = 128M */upload_max_filesize = 24M/" /etc/php5/apache2/php.ini
echo -e "\n--- Setting up upload_max_filesize to 24M ---\n"
sed -i "s/upload_max_filesize = 2M */upload_max_filesize = 24M/" /etc/php5/apache2/php.ini
echo -e "\n--- Setting up post_max_size to 24M ---\n"
sed -i "s/post_max_size = 8M */post_max_size = 24M/" /etc/php5/apache2/php.ini
echo -e "\n--- Setting up  max_execution_time to 240 ---\n"
sed -i "s/max_execution_time = 30 */max_execution_time = 240/" /etc/php5/apache2/php.ini
echo -e "\n--- Setting up  max_input_vars to 1500 ---\n"
sed -i "s/; max_input_vars = 1000.*/max_input_vars = 1500/" /etc/php5/apache2/php.ini

echo -e "\n--- Configure Apache to use phpmyadmin ---\n"
echo -e "\n\nListen 81\n" >> /etc/apache2/ports.conf
cat > /etc/apache2/conf-available/phpmyadmin.conf << "EOF"
<VirtualHost *:81>
    ServerAdmin webmaster@localhost
    DocumentRoot /usr/share/phpmyadmin
    DirectoryIndex index.php
    ErrorLog ${APACHE_LOG_DIR}/phpmyadmin-error.log
    CustomLog ${APACHE_LOG_DIR}/phpmyadmin-access.log combined
</VirtualHost>
EOF
a2enconf phpmyadmin > /dev/null 2>&1

echo -e "\n--- Add environment variables to Apache ---\n"
cat > /etc/apache2/sites-enabled/000-default.conf <<EOF
<VirtualHost *:80>
    DocumentRoot /var/www/html
    ServerAlias $LOCALDOMAIN
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
    SetEnv APP_ENV $APPENV
    SetEnv DB_HOST $DBHOST
    SetEnv DB_NAME $DBNAME
    SetEnv DB_USER $DBUSER
    SetEnv DB_PASS $DBPASSWD
    SetEnv TYPO3_CONTEXT Development
</VirtualHost>
EOF

echo -e "\n--- Setting up XDEBUG ---\n"
cat > /tmp/xdebug <<EOF
[xdebug]
zend_extension=/usr/lib64/php/modules/xdebug.so
xdebug.remote_enable = 1
; Schaltet Remote Debugging für alle Hosts an
xdebug.remote_connect_back=1
; Schaltet Remote Debugging per default an
xdebug.remote_autostart=1
; Datenverkehr zw. XDebug und IDE in ein logfile schreiben
;xdebug.remote_log=/tmp/xdebug.log
;xdebug.remote_host=84.130.214.73
; Port
xdebug.remote_port=9000
xdebug.max_nesting_level=400
xdebug.default_enable=1
xdebug.idekey = PhpStorm
EOF

cat /tmp/xdebug >> /etc/php5/apache2/php.ini
rm /tmp/xdebug
echo -e "\n--- Restarting Apache ---\n"
service apache2 restart > /dev/null 2>&1


echo -e "\n--- get current TYPO3 ---\n"
cd /var/www
wget get.typo3.org/$TYPO3VER --content-disposition
echo -e "\n--- unpacking TYPO3 ---\n"
tar xfz typo3_src-$TYPO3VER.tar.gz

cd /var/www/html
ln -s ../typo3_src-$TYPO3VER typo3_src
ln -s typo3_src/index.php index.php
ln -s typo3_src/typo3 typo3
cp typo3_src/_.htaccess .htaccess
touch FIRST_INSTALL

echo -e "\n--- Add environment variables locally for artisan ---\n"
cat >> /home/vagrant/.bashrc <<EOF
# Set envvars
export APP_ENV=$APPENV
export DB_HOST=$DBHOST
export DB_NAME=$DBNAME
export DB_USER=$DBUSER
export DB_PASS=$DBPASSWD
EOF