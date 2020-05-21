#!/bin/bash

function dl {
  url=$1
  tar=$(echo $url | awk -F / '{print $NF}')
  file=$(echo $tar | awk -F '.tar.gz' '{print $1}')
  cd /tmp
  wget -P /tmp $url
  tar zxf $tar
  cd /tmp/$file
}

function dlmake {
  url=$1
  param=$2
  archive=$(echo $url | awk -F / '{print $NF}')
  file=$(echo $archive | awk -F . '{printf $1}')
  dl $url
  ./configure $param
  make && make install
  cd /tmp
  rm -rf $archive $file
}

function dependencies_php {
  apt install -y libxml2 libxml2-dev php-fpm fcgiwrap
  sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php/7.3/fpm/php.ini
}

function install_php {
  if [[ $input_soft == "y" ]]; then
    apt install -y php7.3
  else
    dlmake "https://www.php.net/distributions/php-7.3.0.tar.gz" "\
    --enable-mbstring \
    --with-curl \
    --with-openssl \
    --with-zlib \
    --enable-fpm"
  fi
  dependencies_php

  systemctl restart php7.3-fpm
}

function dependencies_nginx {
  if [[ $input_dep == "y" ]]; then
    apt install -y libpcre3 libpcre3-dev zlib1g zlib1g-dev openssl libssl-dev
  else
    dlmake "https://ftp.pcre.org/pub/pcre/pcre-8.43.tar.gz"
    dlmake "http://zlib.net/zlib-1.2.11.tar.gz"
    dlmake "http://www.openssl.org/source/openssl-1.1.1c.tar.gz"
  fi
}

function install_nginx {
  # PATH
  etc="/etc/nginx"
  # AVOID CONFLICT
  systemctl disable apache2
  systemctl stop apache2
  # FIREWALL
  ufw allow 80/tcp
  ufw allow 443/tcp
  mkdir /var/log/nginx /etc/systemd/system/nginx.service.d

  dependencies_nginx
  if [[ $input_soft == "y" ]]; then
    apt install -y nginx
    # BACKUP CONF
    cp $etc/sites-available/default $etc/sites-available/default.default
    cp $etc/nginx.conf $etc/nginx.conf.default
    # SETUP CONF
    cp $pwd/nginx.conf $etc/nginx.conf
    cp $pwd/nagios.conf $etc/sites-available/nagios.conf
    sed -i "s/<IP>/$1/g" $etc/sites-available/nagios.conf
    ln -s $etc/sites-available/nagios.conf $etc/sites-enabled/nagios
  else
    # INSTALL
    dlmake "http://nginx.org/download/nginx-1.17.7.tar.gz" "\
      --prefix=/etc/nginx \
      --sbin-path=/usr/sbin/nginx \
      --modules-path=/usr/lib/nginx/modules \
      --conf-path=/etc/nginx/nginx.conf \
      --error-log-path=/var/log/nginx/error.log \
      --pid-path=/var/run/nginx.pid \
      --lock-path=/var/run/nginx.lock \
      --with-http_ssl_module \
      --with-http_v2_module \
      --with-http_realip_module \
      --http-log-path=/var/log/nginx/access.log \
      --with-debug"
    # SETUP CONF
    mkdir $etc/sites-available $etc/sites-enabled
    cp $pwd/nginx.conf $etc/nginx.conf
    cp $pwd/nagios.conf $etc/sites-available/nagios.conf
    ln -s $etc/sites-available/nagios.conf $etc/sites-enabled/nagios
    # SERVICE
    cp $pwd/nginx.service /lib/systemd/system/nginx.service
    ln -s /lib/systemd/system/nginx.service /etc/systemd/system/multi-user.target.wants/nginx.service
    systemctl daemon-reload
    systemctl enable nginx
  fi
  # SSL
  openssl req -x509 -nodes -days 365 -newkey rsa:4096 -keyout /etc/ssl/private/nagios.key -out /etc/ssl/certs/nagios.crt -subj "/C=FR/ST=IDF/L=Paris/O=IT/OU=Linux/CN=esgi"
  openssl dhparam -out /etc/ssl/certs/dhparam.pem 1024
  systemctl restart nginx
}

function dependencies_nagios {
  apt install -y apache2 php-gd libgd-dev libapache2-mod-php libperl-dev libssl-dev apache2-utils
}

function install_nagios {
  dependencies_nagios
  systemctl disable apache2
  systemctl stop apache2
  # SERVICE USERS
  useradd nagios
  groupadd nagcmd
  usermod -aG nagcmd nagios
  usermod -aG nagcmd www-data
  usermod -aG nagios www-data
  systemctl restart nginx
  # INSTALL
  dl "https://assets.nagios.com/downloads/nagioscore/releases/nagios-4.4.5.tar.gz"
  ./configure --with-nagios-group=nagios --with-command-group=nagcmd --with-httpd_conf=/etc/apache2/sites-enabled/
  make all
  make install
  make install-init
  make install-config
  make install-commandmode
  make install-webconf
  # BASIC AUTH
  htpasswd -bc /usr/local/nagios/etc/htpasswd.users nagiosadmin nagiosadmin
  # NAGIOS PLUGIN
  dlmake "https://nagios-plugins.org/download/nagios-plugins-2.2.1.tar.gz" "\
  --with-nagios-user=nagios \
  --with-nagios-group=nagios"
  systemctl daemon-reload
  systemctl enable nagios
  systemctl start nagios
}

function install_squid {
  if [[ $input_dep == "y" ]]; then
    apt install -y squid
  else
    dlmake "http://www.squid-cache.org/Versions/v4/squid-4.10.tar.gz" "\
    --prefix=/usr \
    --localstatedir=/var \
    --libexecdir=${prefix}/lib/squid \
    --datadir=${prefix}/share/squid \
    --sysconfdir=/etc/squid \
    --with-default-user=proxy \
    --with-pidfile=/var/run/squid.pid \
    --with-openssl \
    --enable-icmp"
  fi
  echo -e "www.google.com\ngoogle.com" > /etc/squid/acl
  cp $pwd/squid.conf /etc/squid
  ufw allow 3128
  systemctl restart squid
}

function dependencies_squidguard {
  if [[ $input_dep == "y" ]]; then
    apt install -y bison flex libdb-dev
  else
    dlmake "ftp://ftp.gnu.org/gnu/bison/bison-3.5.tar.gz"
    dlmake "https://sourceforge.net/projects/flex/files/flex-2.6.0.tar.gz/download"
    dlmake "https://download.oracle.com/berkeley-db/db-4.6.21.tar.gz" "--prefix=/usr/local/berkeleydb"
  fi
}

function install_squidguard {
  dependencies_squidguard

  if [[ $input_soft == "y" ]]; then
    apt install -y squidguard
  else
    echo "/usr/local/berkeleydb/lib/" >> /etc/ld.so.conf
    mkdir /etc/squidguard /var/log/squidguard /var/lib/squidguard /var/lib/squidguard/db
    chown -R squid /var/log/squidguard /var/lib/squidguard /etc/squidguard
    dlmake "http://www.squidguard.org/Downloads/squidGuard-1.3.tar.gz/" "\
    --sysconfdir=/etc/squidguard \
    --with-sg-config=/etc/squidguard/squidGuard.conf \
    --with-sg-logdir=/var/log"
    #--with-sg-db=/var/lib/squidguard/db \
    #--prefix=/usr \
    #--localstatedir=/var \
    #--libexecdir=${prefix}/lib/squidguard \
    #--datadir=${prefix}/share/squidguard \
    #--with-sg-logdir=/var/log \
    #--with-sg-config=/etc/squidguard \
    #--with-sg-db=/var/lib/squidguard/db \
    #--with-sg-logdir=/var/log/squidguard"
    apt install -y squidguard
  fi
  # BLACKLISTS
  wget -O /tmp/blacklists.tgz http://squidguard.mesd.k12.or.us/blacklists.tgz
  gzip -d /tmp/blacklists.tgz
  tar xvf /tmp/blacklists.tar -C /tmp
  cp -R /tmp/blacklists/* /var/lib/squidguard/db
  rm -rf /tmp/blacklists/*
  chown proxy:proxy -R /var/lib/squidguard/db/*
  find /var/lib/squidguard/db -type f | xargs chmod 644
  find /var/lib/squidguard/db -type d | xargs chmod 755
  # TO TEST
  echo "youtube.com" >> /var/lib/squidguard/db/warez/domains
  # CONF
  cp $pwd/squidGuard.conf /etc/squidguard
  squidGuard -dC all
  systemctl restart squid
}

function install_script_dependencies {
  apt update
  apt install -y wget ca-certificates gcc make perl automake autoconf build-essential daemon perl ufw unzip
  ufw allow 22
  ufw enable
  systemctl start ufw
}

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

echo "Install software by apt [y/n] ?"
read input_soft
echo "Install dependencies by apt [y/n] ?"
read input_dep
echo "IP or domain ?"
read input_ip

pwd=`pwd`
source $pwd/path.sh
install_script_dependencies
install_php
install_nginx $input_ip
install_nagios
#install_squid
#install_squidguard
ufw reload

echo "Done"
