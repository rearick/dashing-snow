#!/bin/bash -x
#Let's get it started!

#Run system update
yum -y update

#Install needed utilities
yum -y install git
yum -y install htop

#Install smashing JavaScript dependancy
yum -y install nodejs

su -c "source /vagrant/vagrant/user-config.sh" vagrant