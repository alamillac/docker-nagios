#!/bin/bash

#FROM: https://github.com/QuantumObject/docker-nagios/blob/master/pre-conf.sh

#reason of this script is that dockerfile only execute one command at the time but we need sometimes at the moment we create
#the docker image to run more that one software for expecified configuration like when you need mysql running to chnage or create
#database for the container ...

set -e

useradd --system --home /usr/local/nagios -M nagios
groupadd --system nagcmd
usermod -a -G nagcmd nagios
usermod -a -G nagcmd www-data
usermod -G nagios www-data
cd /tmp
wget https://assets.nagios.com/downloads/nagioscore/releases/nagios-4.2.0.tar.gz
wget http://nagios-plugins.org/download/nagios-plugins-2.1.2.tar.gz
wget http://sourceforge.net/projects/nagios/files/nrpe-3.x/nrpe-3.0.tar.gz
tar -xvf nagios-4.2.0.tar.gz
tar -xvf nagios-plugins-2.1.2.tar.gz
tar -xvf nrpe-3.0.tar.gz

#installing nagios
cd /tmp/nagios-4.2.0
./configure --with-nagios-group=nagios --with-command-group=nagcmd --with-mail=/usr/sbin/sendmail --with-httpd_conf=/etc/apache2/conf-available
make all
make install
make install-init
make install-config
make install-commandmode
make install-webconf
cp -R contrib/eventhandlers/ /usr/local/nagios/libexec/
chown -R nagios:nagios /usr/local/nagios/libexec/eventhandlers
mkdir -p /usr/local/nagios/var/spool
mkdir -p /usr/local/nagios/var/spool/checkresults
chown -R nagios:nagios /usr/local/nagios/var
/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
ln -s /etc/init.d/nagios /etc/rcS.d/S99nagios

#installing plugins
cd /tmp/nagios-plugins-2.1.2/
./configure --with-nagios-user=nagios --with-nagios-group=nagios --enable-perl-modules --enable-extra-opts
make
make install

cd /tmp/nrpe-3.0/
./configure --with-nrpe-user=nagios --with-nrpe-group=nagios --with-nagios-user=nagios --with-nagios-group=nagios  --with-ssl=/usr/bin/openssl --with-ssl-lib=/usr/lib/x86_64-linux-gnu
make all
make install-plugin

#installing check_rabbitmq Plugin
cd /tmp
wget --no-check-certificate https://github.com/jamesc/nagios-plugins-rabbitmq/archive/master.zip
unzip master.zip
rm master.zip
mv nagios-plugins-rabbitmq-master/scripts/ /usr/local/nagios/libexec/rabbitmq/

#check_rabbitmq dependencies:
export PERL_MM_USE_DEFAULT=1
cpan inc::Module::Install
cpan Params::Validate
cpan Math::Calc::Units
cpan Config::Tiny
cpan JSON
cpan Class::Accessor
cpan LWP::UserAgent

wget https://github.com/monitoring-plugins/monitoring-plugin-perl/archive/master.zip
unzip master.zip
cd monitoring-plugin-perl-master
perl Makefile.PL
make
make install

#to fix error relate to ip address of container apache2
echo "ServerName localhost" | tee /etc/apache2/conf-available/fqdn.conf
ln -s /etc/apache2/conf-available/fqdn.conf /etc/apache2/conf-enabled/fqdn.conf

a2enmod cgi

htpasswd -b -c /usr/local/nagios/etc/htpasswd.users nagiosadmin admin
sed -i 's/#Include.*/Include conf-available\/nagios.conf/' /etc/apache2/sites-enabled/000-default.conf
rm -rf /tmp/* /var/tmp/*
