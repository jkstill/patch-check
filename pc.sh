#!/bin/sh

# set the environment to call pc.pl. (patch check)
# the LD_LIBRARY_PATH 

OHOMES_FILE=oracle_homes.txt
PATCH_LIST_FILE=patch_list.txt

[ -r "$OHOMES_FILE" ] || {
	echo The file $OHOMES_FILE is missing
	exit 1
}


while read ohome
do
	sid=$(basename $ohome)
	LOGFILE=patch-check_${sid}.log
	ERRFILE=patch-check_${sid}.err

	echo $ohome

	# you may have to experiment a bit to get the needed paths in LD_LIBRARY_PATH
	# in 11g there will probably still be a few files that need to be checked manually
	export LD_LIBRARY_PATH=$ohome/lib:$ohome/jdk/jre/lib/amd64:$ohome/jdk/jre/lib/amd64/server

	./pc.pl  -verbosity 1 -oracle_home $ohome -linux_patch_list $PATCH_LIST_FILE >$LOGFILE 2>$ERRFILE

done < $OHOMES_FILE


