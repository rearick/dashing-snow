#!/bin/sh -x

/usr/sbin/logrotate -v /vagrant/snowData/snowDataRotate.conf
EXITVALUE=$?
if [ $EXITVALUE != 0 ]; then
    /usr/bin/logger -t logrotate "ALERT exited abnormally with [$EXITVALUE]"
fi
exit 0