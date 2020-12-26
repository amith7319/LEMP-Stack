#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi
read -p "Enter the system hostname:  " HOSTNAME
hostnamectl set-hostname $HOSTNAME

yum update -y
yum install wget epel-release curl nano -y

## Installing Mariadb

if [ ! -x /usr/bin/mysql ];
   then
      echo "MARIADB will be INSTALLED now"
      yum -y install mariadb mariadb-server
      systemctl start mariadb
      systemctl enable mariadb
   else
      echo -----------------------------------------------------------------------------
      echo "MARIADB is already INSTALLED"
      echo -----------------------------------------------------------------------------
      exit 1
fi
password=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)
echo Mysql root password = $password > /root/LEMPpassword.txt
mysql_secure_installation <<EOF

y
$password
$password
y
n
y
y
EOF

# Installing Nginx

if [ ! -x /usr/sbin/nginx ];
    then
        echo "NGINX will be INSTALLED now"
        yum install nginx -y
        systemctl start nginx
        systemctl enable nginx
    else
        echo -----------------------------------------------------------------------------
        echo "NGINX is already INSTALLED"
        echo -----------------------------------------------------------------------------
fi


## Installing PHP

if [ ! -x /usr/bin/php ];
   then
      echo "PHP will be INSTALLED now"
      yum install http://rpms.remirepo.net/enterprise/remi-release-7.rpm -y
      yum --disablerepo="*" --enablerepo="remi-safe" list php[7-9][0-9].x86_64 |grep php
      echo -----------------------------------------------------------------------------
      read -p "Select one PHP version from above...like php70,php71,php80  " PHPV
      echo -----------------------------------------------------------------------------
      yum-config-manager --enable remi-$PHPV
      yum install php-fpm php-opcache php-cli php-gd php-curl php-mysql -y
   else
      echo -----------------------------------------------------------------------------
      echo "PHP is already installed"
      echo -----------------------------------------------------------------------------
fi

#Changing PHP-FPM according to Nginx

sed -i 's/user = apache/user = nginx/g' /etc/php-fpm.d/www.conf
sed -i 's/group = apache/group = nginx/g' /etc/php-fpm.d/www.conf
sed -i 's/listen.owner = apache/listen.owner = nginx/g' /etc/php-fpm.d/www.conf
sed -i 's/listen.group = apache/listen.group = nginx/g' /etc/php-fpm.d/www.conf
sed -i 's/;listen = 127.0.0.1:9000/listen = /run/php-fpm/www.sock/g' -- /etc/php-fpm.d/www.conf
chown -R root:nginx /var/lib/php
systemctl enable php-fpm
systemctl start php-fpm

#Configuring TEST block NGINX

IP=$(curl checkip.amazonaws.com)
touch /etc/nginx/conf.d/default.conf
cat > /etc/nginx/conf.d/default.conf << EOL
server {
    listen       80;
    server_name  $IP $HOSTNAME;

    root   /usr/share/nginx/html;
    index index.php index.html index.htm;

    location / {
        try_files $uri $uri/ =404;
    }
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;

    location = /50x.html {
        root /usr/share/nginx/html;
    }

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_pass unix:/run/php-fpm/www.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOL

touch /usr/share/nginx/html/info.php
cat > /usr/share/nginx/html/info.php << EOL
<?php
phpinfo();
?>
EOL

systemctl restart nginx

echo ...............................Finished...Installation....!!!
echo " Visit....http://server_hostname_or_IP/info.php"
