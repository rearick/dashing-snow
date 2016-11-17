#!/bin/bash
# Control variables
ROTATENUM=16 # Maximum number of files to accumulate
BASENAME="dashingFeed" # Filename
EXTENSION="xls" # File extension
SERIALBASE=1000 # Placeholder digits needed for convenient file system level sorting
DIR="/home/drearick/ownCloud/IFTTT"

# Push file list into the files array and store file count
files=(`cd $DIR; ls ${BASENAME}*`)
fileCount=${#files[@]}

# Exit if no new file
if [ ${files[(($fileCount - 1))]} != $BASENAME.$EXTENSION ]
	then
	exit
fi

# Move new file from the end of the files array to the beginning
if [ $fileCount -ne 1 ]
	then
	tmpVar=${files[(($fileCount - 1))]}
	i=$(($fileCount - 1))
	while [ $i -gt 0 ]
	do
		files[$i]=${files[(($i - 1))]}
		i=$(($i - 1))
	done
	files[0]=$tmpVar
fi

# Exit on error function
catchException() {
	if [ $? -ne 0 ]
		then
		exit
	fi
}

# File rotation function
shuffle() {
	mv $DIR/$2 $DIR/$3
	catchException
	mv $DIR/$1 $DIR/$4
	catchException
}

i=0 # Set while loop iterator
# Iterate over files array to execute file rotation
while [ $i -lt $ROTATENUM ]
do
	# Handle cases where there are less files than the allowed maximum
	if [ $ROTATENUM -gt $fileCount ]
		then
		# Stop if file rotation is complete
		if [ $(($i + 1)) -gt $fileCount ]
			then
			i=$ROTATENUM
			continue
		# When only one file exists rename it with S/N 1001
		elif [ $fileCount -eq 1 ]
			then
			mv $DIR/${files[$i]} $DIR/$BASENAME.$(($i + 1 + $SERIALBASE)).$EXTENSION
			catchException

			i=$(($i + 1))
			continue
		fi
	fi

	# Set file rotation function arguments for first iteration
	if [ $i -eq 0 ]
		then
		arg1=${files[$i]}
		arg2=${files[(($i + 1))]}
		arg3=$BASENAME.tmp.$EXTENSION
	# Set file rotation function arguments for odd interations
	elif [ $(($i % 2)) -eq 1 ]
		then
		arg1=$BASENAME.tmp.$EXTENSION
		arg2=${files[(($i + 1))]}
		arg3=$BASENAME.pmt.$EXTENSION
	# Set file rotation function arguments for even interations
	else
		arg1=$BASENAME.pmt.$EXTENSION
		arg2=${files[(($i + 1))]}
		arg3=$BASENAME.tmp.$EXTENSION
	fi

	# Set destination filename for current iteration
	arg4=$BASENAME.$(($i + 1 + $SERIALBASE)).$EXTENSION

	# Call the file rotation function and pass in prepared arguments
	shuffle $arg1 $arg2 $arg3 $arg4

	# Handle cases where maximum allowed is greater than or equal to file count
	if [ $ROTATENUM -ge $fileCount ]
		then
		# Execute last file rotation and quit
		if [ $(($i + 2)) -eq $fileCount ]
			then
			mv $DIR/$arg3 $DIR/$BASENAME.$(($i + 2 + $SERIALBASE )).$EXTENSION

			i=$ROTATENUM
			continue
		fi
	fi

	# Handle cases where the new file exceeds the maximum number of files to retain
	if [ $ROTATENUM -lt $fileCount ]
		then
		# Drop oldest file on last iteration
		if [ $i -eq $(($ROTATENUM - 1)) ]
			then
			rm -f $DIR/$arg3
		fi
	fi

	i=$(($i + 1))
done

