#!/bin/sh
ROTATENUM=9
BASENAME="test.txt"
DIR="/vagrant/snowData/IFTTT"

files=`cd ${DIR}; ls ${BASENAME}*` # <- INCORRECT ASSIGNMENT
echo "${files[1]}"

if [ $files[0] != $BASENAME ]
	then
	exit
fi

if [ $files[0] == $BASENAME ]
	then
	echo "Match!"
fi

shuffle() {
	mv $DIR/$2 $DIR/$BASENAME
	mv $DIR/$1 $DIR/$2
}