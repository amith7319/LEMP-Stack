#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi
yum update -y
yum upgrade -y
yum install wget epel-release curl nano -y
if [ ! -x /usr/sbin/nginx ];
    then
        echo "NGINX is being INSTALLED" && yum install nginx -y && systemctl start nginx && systemctl enable nginx
    else
        systemctl restart nginx && echo "NGINX is INSTALLED and RUNNING"
fi
yum -y install mariadb mariadb-server
systemctl start mariadb && systemctl enable mariadb
VERSION=`mysql -V |awk '{print $5}' |sed "s/-[[:alpha:]].*$//"`
if [ -z "`mysql -V |grep -i mariadb`" ]; then # There is MySQL server
 if [[ "$VERSION" > "5.6.9" ]]; then 
    NEW=1
    else
    NEW=0
 fi
else # There is MariaDB server 10.4
 if [[ "$VERSION" > "10.4" ]]; then 
    NEW=1
    else
    NEW=0
    yum -y upgrade 
 fi
fi
