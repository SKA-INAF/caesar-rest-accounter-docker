#!/bin/bash

##########################
##    PARSE ARGS
##########################
RUNUSER="caesar"
DATADIR="/opt/caesar-rest/data"
JOBDIR="/opt/caesar-rest/jobs"
DBHOST="127.0.0.1"
DBNAME="caesardb"
DBPORT=27017
JOB_MONITORING_PERIOD=30
MOUNT_RCLONE_VOLUME=0
MOUNT_VOLUME_PATH="/mnt/storage"
RCLONE_REMOTE_STORAGE="neanias-nextcloud"
RCLONE_REMOTE_STORAGE_PATH="."
RCLONE_MOUNT_WAIT_TIME=10


echo "ARGS: $@"

for item in "$@"
do
	case $item in
		--runuser=*)
    	RUNUSER=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--datadir=*)
    	DATADIR=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--jobdir=*)
    	JOBDIR=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--job-monitoring-period=*)
    	JOB_MONITORING_PERIOD=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--dbhost=*)
    	DBHOST=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--dbport=*)
    	DBPORT=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--dbname=*)
    	DBNAME=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--mount-rclone-volume=*)
    	MOUNT_RCLONE_VOLUME=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--mount-volume-path=*)
    	MOUNT_VOLUME_PATH=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--rclone-remote-storage=*)
    	RCLONE_REMOTE_STORAGE=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--rclone-remote-storage-path=*)
    	RCLONE_REMOTE_STORAGE_PATH=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--rclone-mount-wait=*)
    	RCLONE_MOUNT_WAIT_TIME=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;

	*)
    # Unknown option
    echo "ERROR: Unknown option ($item)...exit!"
    exit 1
    ;;
	esac
done



###############################
##    MOUNT VOLUMES
###############################
if [ "$MOUNT_RCLONE_VOLUME" = "1" ] ; then

	# - Create mount directory if not existing
	echo "INFO: Creating mount directory $MOUNT_VOLUME_PATH ..."
	mkdir -p $MOUNT_VOLUME_PATH	

	# - Get device ID of standard dir, for example $HOME
	#   To be compared with mount point to check if mount is ready
	DEVICE_ID=`stat "$HOME" -c %d`
	echo "INFO: Standard device id @ $HOME: $DEVICE_ID"

	# - Mount rclone volume in background
	uid=`id -u $RUNUSER`

	echo "INFO: Mounting rclone volume at path $MOUNT_VOLUME_PATH for uid/gid=$uid ..."
	MOUNT_CMD="/usr/bin/rclone mount --daemon --uid=$uid --gid=$uid --umask 000 --allow-other --file-perms 0777 --dir-cache-time 0m5s --vfs-cache-mode full $RCLONE_REMOTE_STORAGE:$RCLONE_REMOTE_STORAGE_PATH $MOUNT_VOLUME_PATH -vvv"
	eval $MOUNT_CMD

	# - Wait until filesystem is ready
	echo "INFO: Sleeping $RCLONE_MOUNT_WAIT_TIME seconds and then check if mount is ready..."
	sleep $RCLONE_MOUNT_WAIT_TIME
	
	# - Get device ID of mount point
	MOUNT_DEVICE_ID=`stat "$MOUNT_VOLUME_PATH" -c %d`
	echo "INFO: MOUNT_DEVICE_ID=$MOUNT_DEVICE_ID"
	if [ "$MOUNT_DEVICE_ID" = "$DEVICE_ID" ] ; then
 		echo "ERROR: Failed to mount rclone storage at $MOUNT_VOLUME_PATH within $RCLONE_MOUNT_WAIT_TIME seconds, exit!"
		exit 1
	fi

	# - Print mount dir content
	echo "INFO: Mounted rclone storage at $MOUNT_VOLUME_PATH with success (MOUNT_DEVICE_ID: $MOUNT_DEVICE_ID)..."
	ls -ltr $MOUNT_VOLUME_PATH

	# - Create job & data directories
	echo "INFO: Creating job & data directories ..."
	mkdir -p 	$MOUNT_VOLUME_PATH/jobs
	mkdir -p 	$MOUNT_VOLUME_PATH/data

fi



###############################
##    SET CMD ARGS
###############################
RCLONE_OPTS=""
if [ "$MOUNT_RCLONE_VOLUME" = "1" ] ; then
	RCLONE_OPTS="--mount_rclone_volume --mount_volume_path=$MOUNT_VOLUME_PATH	--rclone_storage_name=$RCLONE_REMOTE_STORAGE --rclone_storage_path=$RCLONE_REMOTE_STORAGE_PATH "
fi


###############################
##    RUN ACCOUNTER
###############################
# - Define run command & args
CMD="runuser -l $RUNUSER -g $RUNUSER -c'""/opt/caesar-rest/bin/run_accounter.py --datadir=$DATADIR --jobdir=$JOBDIR --job_monitoring_period=$JOB_MONITORING_PERIOD --dbhost=$DBHOST --dbname=$DBNAME --dbport=$DBPORT $RCLONE_OPTS ""'"

# - Run command
echo "INFO: Running command: $CMD ..."
eval "$CMD"

