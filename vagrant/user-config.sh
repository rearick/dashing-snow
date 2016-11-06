#!/bin/bash -x
#Set Ruby Version
RBVER="2.3.0"
SHARE_DIR="/vagrant"
PROJ_DIR="dashing_p_o_c"

#Add .profile to .bash_profile
if [ -f ~/.profile ]; then
	echo ". ~/.profile" >> ~/.bash_profile
fi

#Install RVM
gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
curl -sSL https://get.rvm.io | bash -s stable
source "$HOME/.rvm/scripts/rvm"

#Install Ruby
rvm install $RBVER
rvm use $RBVER --default

#Install any needed gems
gem install bundler
gem install smashing

[ ! -d $SHARE_DIR/$PROJ_DIR ] && cd $SHARE_DIR &&  smashing new $PROJ_DIR

#Run bundler in the project directory but no more than 10 times
cd $SHARE_DIR/$PROJ_DIR
i="0"
successFlag="5"
while [[ $successFlag -eq 5 && $i -lt 10 ]]
do
	bundle
	successFlag=$?
	i=$[$i+1]
done