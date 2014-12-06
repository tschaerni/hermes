#!/bin/bash
# Doomsider's and Titanmasher's Daemon Script for Starmade.  init.d script 7/10/13 based off of http://paste.boredomsoft.org/main.php/view/62107887
# All credits to Andrew for his initial work
# Scrubbed down version "DTSDlite"
# Version 0.9.0-alpha 30.11.2014
# Jstack for a dump has been added into the ebrake command to be used with the detect command to see if server is responsive.
# These dumps will be in starterpath/logs/threaddump.log and can be submitted to Schema to troubleshoot server crashes
# !!!You must update starmade.cfg for the Daemon to work on your setup!!!
# The daemon should be ran from the intended user as it detects and writes the current username to the configuration file

#For development purposes update check can be turned off
UPDATECHECK=YES
# Set the basics paths for the Daemon automatically.  This can be changed if needed for alternate configurations
# This sets the path of the script to the actual script directory.  This is some magic I found on stackoverflow http://stackoverflow.com/questions/4774054/reliable-way-for-a-bash-script-to-get-the-full-path-to-itself	
DAEMONPATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)/`basename "${BASH_SOURCE[0]}"`
CONFIGPATH="$(echo $DAEMONPATH | cut -d"." -f1).cfg"
# Set the starter path to the correct directory.  rev here is used to make the string backwards so that it can be cut at the last forward slash 
STARTERPATH=$(echo $DAEMONPATH | rev | cut -d"/" -f2- | rev)
ME=`whoami`
# Grab the current hash from the Daemon
CURRENTHASH=$(md5sum $DAEMONPATH |  cut -d" " -f1 | tr -d ' ')
# Since this is a Daemon it can be called on from anywhere from just about anything.  This function below ensures the Daemon is using the proper user for the correct privileges
as_user() {
if [ "$ME" == "$USERNAME" ] ; then
	bash -c "$1"
else
	su - $USERNAME -c "$1"
fi
}

#------------------------------Daemon functions-----------------------------------------

depcheck() {
# Dependency check for the whole daemon

# initialize variable
NOT_INSTALLED=""

# check for all dep's
# special thanks to hrnz for this hint
for i in zip unzip screen rlwrap java jstack ; do
	if ! which $i > /dev/null; then
		NOT_INSTALLED="$NOT_INSTALLED $i"
	fi
done

# abort if some of the dep's aren't present
if [ ! -z "$NOT_INSTALLED" ] ; then
	echo "Terminate the daemon..."
	echo "There are some dependencies that aren't present on this system. Please install$NOT_INSTALLED manually"
	exit 1
fi
}

sm_config() {
# Check to see if the config file is in place, if it is then see if an update is needed.  If it does not exist create it and other needed files and directories.
if [ -e $CONFIGPATH ]
then
	if [ "$UPDATECHECK" = "YES" ]
	then
#		echo "Checking HASH to see if Daemon was updated"
# Grab the hash from the config file and compare it tot he Daemon's hash to see if the Daemon has been updated	
		CONFIGHASH=$(grep HASH $CONFIGPATH | cut -d= -f2 | tr -d ' ')
		if [ "$CONFIGHASH" = "$CURRENTHASH" ]
		then
#			echo "No update detected, Reading from Source $CONFIGPATH"
			source $CONFIGPATH
		else
			echo "Changes detected updating config files"
# Source read from another file.  In this case it is the config file containing all the settings for the Daemon
			source $CONFIGPATH
			update_daemon
		fi
	else
#		echo "Update check is turned off reading source from config file"
		source $CONFIGPATH
	fi
else
# If no config file present set the username temporarily to the current user
	USERNAME=$(whoami)
	echo "Creating configuration file please edit configuration file (ie: starmade.cfg) or script may not function as intended"
# The following creates the directories and configuration files
	create_configpath
	source $CONFIGPATH
	sm_checkdir
	create_tipfile
	create_rankscommands
	exit
fi
}
sm_checkdir() {
	if [ ! -d "$STARTERPATH/logs" ]
	then
		echo "No logs directory detected creating for logging"
		as_user "mkdir $STARTERPATH/logs"
	fi
	if [ ! -d "$PLAYERFILE" ]
	then
		echo "No playerfile directory detected creating for logging"
		as_user "mkdir $PLAYERFILE"
	fi
	if [ ! -d "$FACTIONFILE" ]
	then
		echo "No factionfile directory detected creating for logging"
		as_user "mkdir $FACTIONFILE"
	fi
	if [ ! -d "$STARTERPATH/oldlogs" ]
	then
		echo "No oldlogs directory detected creating for logging"
		as_user "mkdir $STARTERPATH/oldlogs"
	fi
}
sm_start() { 
# Wipe and dead screens to prevent a false positive for a running Screenid
screen -wipe
# Check to see if StarMade is installed
if [ ! -d "$STARTERPATH/StarMade" ]
then
	echo "No StarMade directory found.  Either unzip a backup or run install"
	exit
fi
# Check if server is running already by checking for Screenid in the screen list
if ps aux | grep $SERVICE | grep -v grep | grep -v rlwrap | grep -v tee | grep port:$PORT >/dev/null
then
	echo "Tried to start but $SERVICE was already running!"
else
	echo "$SERVICE was not running... starting."
# Check to see if logs and other directories exists and create them if they do not
	sm_checkdir
# Make sure screen log is shut down just in case it is still running    
    if ps aux | grep -v grep | grep $SCREENLOG >/dev/null
    then
		echo "Screenlog detected terminating..."
#		PID=$(ps aux | grep -v grep | grep $SCREENLOG | awk '{print $2}')    
#		kill $PID
		as_user "screen -S $SCREENLOG -X quit"
	fi
# Check for the output.log and if it is there move it and save it with a time stamp
    if [ -e /dev/shm/output$PORT.log ] 
    then
		MOVELOG=$STARTERPATH/oldlogs/output_$(date '+%b_%d_%Y_%H.%M.%S').log
		as_user "mv /dev/shm/output$PORT.log $MOVELOG"
    fi
# Execute the server in a screen while using tee to move the Standard and Error Output to output.log
	cd $STARTERPATH/StarMade
	as_user "screen -dmS $SCREENID -m sh -c 'rlwrap java -Xmx$MAXMEMORY -Xms$MINMEMORY -jar $SERVICE -server -port:$PORT 2>&1 | tee /dev/shm/output$PORT.log'"
# Created a limited loop to see when the server starts
    for LOOPNO in {0..7}
	do
		if ps aux | grep $SERVICE | grep -v grep | grep -v rlwrap | grep -v tee | grep port:$PORT >/dev/null
		then
			break
		else
			echo "Service not running yet... Waiting...."
			sleep 1
		fi
	done
    if ps aux | grep $SERVICE | grep -v grep | grep -v rlwrap | grep -v tee | grep port:$PORT >/dev/null 
    then
		echo "$SERVICE is now running."
		as_user "echo '' > $ONLINELOG"
# Start sm_screenlog if logging is set to yes
		if [ "$LOGGING" = "YES" ]
		then
			sm_screenlog
		fi
    else
		echo "Could not start $SERVICE."
    fi  
fi
}
sm_stop() {
if ps aux | grep $SERVICE | grep -v grep | grep -v rlwrap | grep -v tee | grep port:$PORT >/dev/null
then
	echo "$SERVICE is running... stopping."
# Issue Chat and a command to the server to shutdown
	as_user "screen -p 0 -S $SCREENID -X eval 'stuff \"/chat Server Going down, be back in a bit.\"\015'"
	as_user "screen -p 0 -S $SCREENID -X eval 'stuff \"/shutdown 60\"\015'"
# Give the server a chance to gracefully shutdown if not kill it and then seg fault it if necessary
	sleep 60
	for LOOPNO in {0..60}
	do
		if ps aux | grep $SERVICE | grep -v grep | grep -v rlwrap | grep -v tee | grep port:$PORT >/dev/null
		then
			sleep 1
		else
			echo $SERVICE took $LOOPNO seconds to close
			as_user "screen -S $SCREENLOG -X quit"
			break
		fi
	done
	if ps aux | grep $SERVICE | grep -v grep | grep -v rlwrap | grep -v tee | grep port:$PORT >/dev/null
    then
		echo $SERVICE is taking too long to close and may be frozen. Forcing shut down
		PID=$(ps aux | grep -v grep | grep $SERVICE | grep -v tee | grep port:$PORT | awk '{print $2}')
		kill $PID
		for LOOPNO in {0..60}
		do
			if ps aux | grep $SERVICE | grep -v grep | grep -v rlwrap | grep -v tee | grep port:$PORT >/dev/null 
			then
				sleep 1
			else
				echo $SERVICE took $(($LOOPNO + 30)) seconds to close, and had to be force shut down
				as_user "screen -S $SCREENLOG -X quit"
				break
			fi
		done
		if ps aux | grep $SERVICE | grep -v grep | grep -v rlwrap | grep -v tee | grep port:$PORT >/dev/null 
		then
			PID=$(ps aux | grep -v grep | grep $SERVICE | grep -v tee | grep port:$PORT | awk '{print $2}')
			kill -9 $PID
# This was added in to troubleshoot freezes at the request of Schema			
			as_user "screen -S $SCREENLOG -X quit"
			screen -wipe
			$SERVICE took too long to close. $SERVICE had to be killed
		fi
	fi
	else
		echo "$SERVICE not running"
  fi
}
sm_backup() {
	if ps aux | grep $SERVICE | grep -v grep | grep -v rlwrap | grep -v tee | grep port:$PORT >/dev/null
	then
		echo "$SERVICE is running! Will not start backup."
	else
		echo "Backing up starmade data" 
	
		if [ -d "$BACKUP" ] 
		then
			cd $STARTERPATH 
			as_user "zip -r $BACKUPNAME$(date '+%b_%d_%Y_%H.%M.%S').zip StarMade"
			as_user "mv $BACKUPNAME*.zip $BACKUP"
			echo "Backup complete"
		else
			echo "Directory not found attempting to create"
			cd $STARTERPATH
			as_user "mkdir $BACKUP"
# Create a zip of starmade with time stamp and put it in backup
			as_user "zip -r $BACKUPNAME$(date '+%b_%d_%Y_%H.%M.%S').zip StarMade"
			as_user "mv $BACKUPNAME*.zip $BACKUP"
			echo "Backup complete" 
		fi
	fi
}
sm_livebackup() {
# WARNING! Live Backup make only a Backup of the Database! Because, some other dirs and files are in use
if ps aux | grep $SERVICE | grep -v grep | grep -v rlwrap | grep -v tee | grep port:$PORT >/dev/null
then
	if [ -d "$BACKUP" ]
	then
		cd $STARTERPATH
		as_user "screen -p 0 -S $SCREENID -X stuff $'/chat Starting live-backup\n'"
		echo "Starting live-backup"
		as_user "screen -p 0 -S $SCREENID -X stuff $'/force_save\n'"
		sleep 10
# /delay_save prevents saving of the Server
		as_user "screen -p 0 -S $SCREENID -X stuff $'/delay_save 3600\n'"
		sleep 5
# Create a zip of starmade with time stamp and put it in backup
		as_user "zip -r $BACKUPNAME$(date '+%b_%d_%Y_%H.%M.%S').zip StarMade/server-database"
		if [ "$?" == "0" ]
		then
			as_user "mv $BACKUPNAME*.zip $BACKUP"
			as_user "screen -p 0 -S $SCREENID -X stuff $'/chat live-backup complete and successfull\n'"
			echo "live-backup complete and successfull"
		else
			as_user "screen -p 0 -S $SCREENID -X stuff $'/chat live-backup exited with error. Please contact the admins.\n'"
			echo "live-backup exited with error. Please check"
		fi
		as_user "screen -p 0 -S $SCREENID -X stuff $'/delay_save 1\n'"
		as_user "screen -p 0 -S $SCREENID -X stuff $'/force_save\n'"
	else
		echo "Directory not found attempting to create"
		cd $STARTERPATH
		as_user "mkdir $BACKUP"
		as_user "screen -p 0 -S $SCREENID -X stuff $'/chat Starting live-backup\n'"
		echo "Starting live-backup"
		as_user "screen -p 0 -S $SCREENID -X stuff $'/force_save\n'"
		sleep 10
		as_user "screen -p 0 -S $SCREENID -X stuff $'/delay_save 3600\n'"
		sleep 5
		as_user "zip -r $BACKUPNAME$(date '+%b_%d_%Y_%H.%M.%S').zip StarMade/server-database"
		if [ "$?" == "0" ]
		then
			as_user "mv $BACKUPNAME*.zip $BACKUP"
			as_user "screen -p 0 -S $SCREENID -X stuff $'/chat live-backup complete and successfull\n'"
			echo "live-backup complete and successfull"
		else
			as_user "screen -p 0 -S $SCREENID -X stuff $'/chat live-backup exited with error. Please contact the admins.\n'"
			echo "live-backup exited with error. Please check"
		fi
		as_user "screen -p 0 -S $SCREENID -X stuff $'/delay_save 1\n'"
		as_user "screen -p 0 -S $SCREENID -X stuff $'/force_save\n'"
	fi
else
	echo "$SERVICE isn't running, make a regular backup"
	sm_backup
fi
}
sm_destroy() {
if ps aux | grep $SERVICE | grep -v grep | grep -v rlwrap | grep -v tee | grep port:$PORT >/dev/null
then
	echo "$SERVICE is running! Will not start destroy."
else
	echo "Destroying all Starmade data" 
# Change to root directory of starmade
	cd $STARTERPATH
# Erase StarMade
	as_user "rm -r StarMade"
echo "Erase complete"
fi
}
sm_install() {
if ps aux | grep $SERVICE | grep -v grep | grep -v rlwrap | grep -v tee | grep port:$PORT >/dev/null
then
	echo "$SERVICE is running! Will not start install"
else
	echo "Installing all Starmade data"
# Check to see if the starter file is present or not
	if [ -f $STARTERPATH/StarMade-Starter.jar ]
	then
		echo "Starter file found running install"
		cd $STARTERPATH
		as_user "java -jar StarMade-Starter.jar -nogui"
	else
		echo "Starter file not found downloading and running install"
# Grab the starmade starter file for Linux - This location may need to be updated in the future
		cd $STARTERPATH
		as_user "wget http://files.star-made.org/StarMade-Starter.jar"
# Execute the starters update routine for a headless server
		as_user "java -jar StarMade-Starter.jar -nogui"
	fi	
fi
echo "Install Complete"
}
sm_upgrade() {
if ps aux | grep $SERVICE | grep -v grep | grep -v rlwrap | grep -v tee | grep port:$PORT >/dev/null
then
	echo "$SERVICE is running! Will not start Install"
else
	echo "Upgrading Starmade"
	cd $STARTERPATH
# Execute the starters update routine for a headless server
	as_user "java -jar StarMade-Starter.jar -nogui"
fi
echo "Upgrade Complete"	
}
sm_cronstop() {
# Stop Cronjobs to prevent things from running during maintenance
as_user "crontab -r"
echo "Cronjobs stopped"
}
sm_cronrestore() {
# Restore Cronjobs to original state
cd $STARTERPATH
as_user "crontab < cronbackup.dat"
echo "Cronjobs restored"
}
sm_cronbackup() {
# Backup Cronjobs 
cd $STARTERPATH
as_user "crontab -l > cronbackup.dat"
echo "Cronjobs backed up"
}
sm_precheck() {
# A big thanks to MichaelSeph for pointing out the code and Schema for writing it.  Without this help this feature
# would have taken far longer to add.
# Check for latest PRE version and install it 
as_user "wget -q --user dev --password dev -O tmp.html http://files.star-made.org/build/pre/"
RELEASE_URL=$(cat tmp.html | grep -o -E "[^<>]*?.zip" | tail -1)
as_user "rm tmp.html"
# echo $RELEASE_URL
SNEWVERSION1=$(echo $RELEASE_URL | cut -d_ -f2)
# echo $SNEWVERSION1
SNEWVERSION2=$(echo $RELEASE_URL | cut -d_ -f3 | cut -d. -f1)
# echo $SNEWVERSION2
CURRENTVER=$(cat $STARTERPATH/StarMade/version.txt)
# echo $CURRENTVER
OLDSMVER1=$(echo $CURRENTVER | cut -d# -f2 | cut -d_ -f1)
# echo $OLDSMVER1
OLDSMVER2=$(echo $CURRENTVER | cut -d_ -f2)
# echo $OLDSMVER2
if [ "$SNEWVERSION1" -gt "$OLDSMVER1" ] || [ "$SNEWVERSION2" -gt "$OLDSMVER2" ]
then 
	echo "Newer Version Detected"
	cd $STARTERPATH
# At this point the cronjobs and server will need to be stopped and a backup made just in case
    as_user "screen -p 0 -S $SCREENID -X stuff $'/chat New version detected going down for backup and upgrade\n'"
	sm_stop
	sm_backup
	as_user "wget --user dev --password dev http://files.star-made.org/build/pre/$RELEASE_URL"
	as_user "unzip -o $RELEASE_URL -d $STARTERPATH/StarMade"
	as_user "rm installed-version"
	as_user "touch $STARTERPATH/installed-version"
	echo $RELEASE_URL >> $STARTERPATH/installed-version
# At this point the server should started and cronjobs restored
else
	echo "No new version detected"
fi
}
sm_check() {
# Check for latest version and install it 
as_user "wget -q -O tmp.html http://files.star-made.org/build/"
RELEASE_URL=$(cat tmp.html | grep -o -E "[^<>]*?.zip" | tail -1)
as_user "rm tmp.html"
# echo $RELEASE_URL
SNEWVERSION1=$(echo $RELEASE_URL | cut -d_ -f2)
# echo $SNEWVERSION1
SNEWVERSION2=$(echo $RELEASE_URL | cut -d_ -f3 | cut -d. -f1)
# echo $SNEWVERSION2
CURRENTVER=$(cat $STARTERPATH/StarMade/version.txt)
# echo $CURRENTVER
OLDSMVER1=$(echo $CURRENTVER | cut -d# -f2 | cut -d_ -f1)
# echo $OLDSMVER1
OLDSMVER2=$(echo $CURRENTVER | cut -d_ -f2)
# echo $OLDSMVER2
if [ "$SNEWVERSION1" -gt "$OLDSMVER1" ] || [ "$SNEWVERSION2" -gt "$OLDSMVER2" ]
then 
	echo "Newer Version Detected"
	cd $STARTERPATH
# At this point the cronjobs and server will need to be stopped and a backup made just in case
	as_user "screen -p 0 -S $SCREENID -X stuff $'/chat New version detected going down for backup and upgrade\n'"
	sm_stop
	sm_backup
	as_user "wget http://files.star-made.org/build/$RELEASE_URL"
	as_user "unzip -o $RELEASE_URL -d $STARTERPATH/StarMade"
	as_user "rm installed-version"
	as_user "touch $STARTERPATH/installed-version"
	echo $RELEASE_URL >> $STARTERPATH/installed-version
# At this point the server should started and cronjobs restored
else
	echo "No new version detected"
fi
}
sm_ebrake() {
if ps aux | grep $SERVICE | grep -v grep | grep -v rlwrap | grep -v tee | grep port:$PORT >/dev/null
then
	PID=$(ps aux | grep -v grep | grep $SERVICE | grep -v tee | grep -v rlwrap | grep port:$PORT | awk '{print $2}')    
	jstack $PID >> $STARTERPATH/logs/threaddump.log
	kill $PID
# Give server a chance to gracefully shut down
	for LOOPNO in {0..30}
	do
		if ps aux | grep $SERVICE | grep -v grep | grep -v rlwrap | grep -v tee | grep port:$PORT >/dev/null
		then
			sleep 1
		else
			echo $SERVICE closed after $LOOPNO seconds
			as_user "screen -S $SCREENLOG -X quit"
			break
		fi
	done
# Check to make sure server is shut down if not kill it with a seg fault.
	if ps aux | grep $SERVICE | grep -v grep | grep -v rlwrap | grep -v tee | grep port:$PORT >/dev/null
	then
		PID=$(ps aux | grep -v grep | grep $SERVICE | grep -v rlwrap | grep -v tee | grep port:$PORT | awk '{print $2}')
# This was added in to troubleshoot freezes at the request of Schema
		jstack $PID >> $STARTERPATH/logs/threaddump1.log
		sleep 10
		jstack $PID >> $STARTERPATH/logs/threaddump2.log
		sleep 10
		jstack $PID >> $STARTERPATH/logs/threaddump3.log
		kill -9 $PID
		echo $SERVICE has to be forcibly closed. A thread dump has been taken and is saved at $STARTERPATH/logs/threaddump.log and should be sent to schema.
		as_user "screen -S $SCREENLOG -X quit"
		screen -wipe
	fi
else
	echo "$SERVICE not running"
fi
}
sm_detect() {
# Special thanks to Fire219 for providing the means to test this script.  Appreciation to Titansmasher for collaboration.
if ps aux | grep $SERVICE | grep -v grep | grep -v rlwrap | grep -v tee | grep port:$PORT >/dev/null
then
# Add in a routine to check for STDERR: [SQL] Fetching connection 
# Send the curent time as a serverwide message
	if (tail -5 /dev/shm/output$PORT.log | grep "Fetching connection" >/dev/null)
	then 
		echo "Database Repairing itself"
	else
# Set the current to Unix time which is number of seconds since Unix was created.  Next send this as a PM to Unix time which will cause the console to error back Unix time.
		CURRENTTIME=$(date +%s)
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $CURRENTTIME testing\n'"   
		echo "Unix time is $CURRENTTIME"
		sleep 10
# Check output.log to see if message was recieved by server.  The tail variable may need to be adjusted so that the
# log does not generate more lines that it looks back into the log
		if tac /dev/shm/output$PORT.log | grep -m 1 "$CURRENTTIME" >/dev/null
		then
			echo "Server is responding"
			echo "Server time variable is $CURRENTTIME"
        else
			echo "Server is not responding, shutting down and restarting"
			sm_ebrake
			sm_start
		fi
	fi
else
	echo "Starmade is not running!"
	sm_start
fi
}
sm_screenlog () {
# Start logging in a screen
if ps aux | grep $SERVICE | grep -v grep | grep -v rlwrap | grep -v tee | grep port:$PORT >/dev/null
then
	echo "Starmade is running checking for logging."
# Make sure smlog is not already running
	if ps aux | grep $SCREENLOG | grep -v grep >/dev/null
	then
		echo "Logging is already running"
	else
		echo "Starting Logging" 
# Check to see if existing screen log exists and if so move and rename it
		if [ -e $STARTERPATH/logs/screen.log ] 
		then
			MOVELOG=$STARTERPATH/oldlogs/screen_$(date '+%b_%d_%Y_%H.%M.%S').log
			as_user "mv $STARTERPATH/logs/screen.log $MOVELOG"
		fi
		STARTLOG="$DAEMONPATH log"
		as_user "screen -dmS $SCREENLOG -m sh -c '$STARTLOG 2>&1 | tee $STARTERPATH/logs/screen.log'"
	fi
fi
}
sm_status () {
# Check to see is Starmade is running or not
if ps aux | grep $SERVICE | grep -v grep | grep -v rlwrap | grep -v tee | grep port:$PORT >/dev/null 
then
	echo "Starmade Server is running."
else
	echo "Starmade Server is NOT running."
fi
}
sm_say() {
# Check to see if server is running and if so pass the second argument as a chat command to server.  Use quotes if you use spaces.
if ps aux | grep $SERVICE | grep -v grep | grep -v rlwrap | grep -v tee | grep port:$PORT >/dev/null
then
	SAYSTRING=$(echo $@ | cut -d" " -f2- | tr -d '<>()!@#$%^&*/[]{},\\' | sed "s/'//g" | sed "s/\"//g")
	as_user "screen -p 0 -S $SCREENID -X stuff $'/chat $SAYSTRING\n'"
else
	echo "Starmade is not running!"
fi
}
sm_do() {
if ps aux | grep $SERVICE | grep -v grep | grep -v rlwrap | grep -v tee | grep port:$PORT >/dev/null
# Check for starmade running the passes second argument as a command on server.  Use quotations if you have spaces in command.
then
	DOSTRING=$(echo $@ | cut -d" " -f2- | tr -d '<>()!@#$%^&*/[]{},\\' | sed "s/'//g" | sed "s/\"//g")
	as_user "screen -p 0 -S $SCREENID -X stuff $'/$2\n'"
else
	echo "Starmade is not running!"
fi
}
sm_restore() {
# Checks for server running and then restores the given backup zip file.  It pulls from the backup directory so no path is needed.
if ps aux | grep $SERVICE | grep -v grep | grep -v rlwrap | grep -v tee | grep port:$PORT >/dev/null
then
	echo "Starmade Server is running."
	else
	cd $BACKUP
	as_user "unzip -o $2 -d $STARTERPATH"
	echo "Server $2 is restored"
fi
}

sm_dump() {
# Check to see if server is running and if so pass the second argument as a chat command to server.  Use quotes if you use spaces.
	if ps aux | grep $SERVICE | grep -v grep | grep -v rlwrap | grep -v tee | grep port:$PORT >/dev/null
	then
		if [ "$#" -ne "2" ] 
		then
			echo "Usage - smdump <amount of thread dumps> <amount of delay between dumps> smdump 2 10"
			exit 
		fi
		PID=$(ps aux | grep -v grep | grep $SERVICE | grep -v tee | grep port:$PORT | awk '{print $2}')    
		count=$2
		delay=$3
		while [ $count -gt 0 ]
		do
			jstack $PID >> $STARTERPATH/logs/threaddump$(date +%H%M%S.%N).log
			sleep $delay
			let count--
		done
		else
		echo "$SERVICE not running"
	fi
}
sm_help() {
echo "updatefiles - Updates all stored files to the latest format, if a change is needed"
echo "start - Starts the server"
echo "stop - Stops the server with a server message and countdown approx 2 mins"
echo "ebrake - Stop the server without a server message approx 30 seconds"
echo "destroy - Deletes Server no recovery"
echo "install - Download a new starter and do a install"
echo "reinstall - Destroys current server and installs new fresh one"
echo "restore <filename> - Selected file unzips into the parent folder of starmade"  
echo "smdo command - Issues a server command.  Use quotes if there are spaces"
echo "smsay words - Say something as the server.  Use quotes if there are spaces"
echo "backup - backs up current Starmade directory as zip"
echo "backupstar - Stops cron and server, makes backup, restarts cron and server"
echo "status - See if server is running"
echo "cronstop - Removes all cronjobs"
echo "cronrestore - Restores all cronjobs"
echo "cronbackup - Backs up your cron file"
echo "upgrade - Runs the starters upgrade routine"
echo "upgradestar - Stops cron and server, runs upgrade, restarts cron and server"
echo "restart - Stops and starts server" 
echo "detect - See if the server is frozen and restart if it is." 
echo "log - Logs admin, chat, player, and kills."
echo "screenlog - Starts the logging function in a screen"
echo "precheck - Checks to see if there is a new pre version, stops server, backs up, and installs it"
echo "check - Checks to see if there is a new version, stops server, backs up, and installs it"
echo "dump - Do a thread dump with number of times and delay between them"
echo "box - Send a colored message box.  Usage: box <red|blue|green> <playername (optional)> <message>"
}
sm_log() {
#Saves the PID of this function being run
SM_LOG_PID=$$
# Chat commands are controlled by /playerfile/playername which contains the their rank and 
# rankcommands.log which has ranks followed by the commands that they are allowed to call
echo "Logging started at $(date '+%b_%d_%Y_%H.%M.%S')"
autovoteretrieval &
randomhelptips &
create_rankscommands
# Create the playerfile folder if it doesnt exist
	mkdir -p $PLAYERFILE
# This while loop runs as long as starmade stays running    
	while (ps aux | grep $SERVICE | grep -v grep | grep -v tee | grep -v rlwrap | grep port:$PORT >/dev/null)
	do
# A tiny sleep to prevent cpu burning overhead
		sleep 0.1
# Uses Cat to calculate the number of lines in the log file
		NUMOFLINES=$(wc -l /dev/shm/output$PORT.log | cut -d" " -f1)
# In case Linestart does not have a value give it an interger value of 1.  The prevents a startup error on the script.
		if [ -z "$LINESTART" ]
		then
			LINESTART=$NUMOFLINES
#			echo "Start at line $LINESTART"
		fi
# If the number of lines read from the log file is greater than last line read + 1 from the log then feed more lines.
		if [ "$NUMOFLINES" -gt "$LINESTART" ] 
		then
#     		echo "$NUMOFLINES is the total lines of the log"
#     		echo "$LINESTART is linestart"
			let LINESTART++
			OLD_IFS=$IFS
# This sets the field seperator to use \n next line instead of next space.  This makes it so the array is a whole sentence not a word
			IFS=$'\n'
# Linestring is stored as an array of every line in the log
			LINESTRING=( $(awk "NR==$LINESTART, NR==$NUMOFLINES" /dev/shm/output$PORT.log) )
			IFS=$OLD_IFS
			LINESTART=$NUMOFLINES
#			echo "$LINESTART is adjusted linestart"
		else
			LINESTRING=()
		fi
# Search strings that the logging function is looking to trigger events
		SEARCHLOGIN="[SERVER][LOGIN] login received. returning login info for RegisteredClient: "
		SEARCHREMOVE="[SERVER][DISCONNECT] Client 'RegisteredClient:"
		SEARCHCHAT="[CHAT]"
		SEARCHCHANGE="has players attached. Doing Sector Change for PlS"
		SEARCHADMIN="[ADMIN COMMAND]"
		SEARCHINIT="SPAWNING NEW CHARACTER FOR PlS"
# Linenumber is set to zero and the a while loop runs through every present array in Linestring	
		LINENUMBER=0
		while [ -n "${LINESTRING[$LINENUMBER]+set}" ] 
		do
#		echo "Current Line in Array $LINENUMBER"
		CURRENTSTRING=${LINESTRING[$LINENUMBER]}
		let LINENUMBER++
# Case statement here is used to match search strings from the current array or line in linestring
		case "$CURRENTSTRING" in
			*"$SEARCHLOGIN"*) 
#				echo "Login detected"
#				echo $CURRENTSTRING
				log_on_login $CURRENTSTRING &
				;;
			*"$SEARCHREMOVE"*) 
#				echo "Remove detected"
#				echo $CURRENTSTRING
				log_playerlogout $CURRENTSTRING &
				;;
 			*"$SEARCHCHAT"*) 
#				echo "Chat detected"
#				echo $CURRENTSTRING
				log_chatcommands $CURRENTSTRING &
				log_chatlogging $CURRENTSTRING &
				;;
			*"$SEARCHCHANGE"*) 
#				echo "Change detected"
#				echo $CURRENTSTRING
				log_sectorchange $CURRENTSTRING &
				;;
			*"$SEARCHADMIN"*) 
#				echo "Admin detected"
#				echo $CURRENTSTRING
				log_admincommand $CURRENTSTRING &
				;;
			*"$SEARCHINIT"*) 
#				echo "Init detected"
				log_initstring $CURRENTSTRING &
				;;
			*) 
				;;
			esac
#			echo "all done"
		done
	done	
}
parselog(){
		SEARCHLOGIN="[SERVER][LOGIN] login received. returning login info for RegisteredClient: "
		SEARCHREMOVE="[SERVER][DISCONNECT] Client 'RegisteredClient:"
		SEARCHCHAT="[CHAT]"
		SEARCHCHANGE="has players attached. Doing Sector Change for PlS"
		SEARCHADMIN="[ADMIN COMMAND]"
		SEARCHINIT="SPAWNING NEW CHARACTER FOR PlS"
		case "$@" in
			*"$SEARCHLOGIN"*) 
#				echo "Login detected"
#				echo $@
				log_on_login $@ &
				;;
			*"$SEARCHREMOVE"*) 
#				echo "Remove detected"
#				echo $@
				log_playerlogout $@ &
				;;
 			*"$SEARCHCHAT"*) 
#				echo "Chat detected"
#				echo $@
				log_chatcommands $@ &
				log_chatlogging $@ &
				;;
			*"$SEARCHCHANGE"*) 
#				echo "Change detected"
#				echo $@
				log_sectorchange $@ &
				;;
			*"$SEARCHADMIN"*) 
#				echo "Admin detected"
#				echo $@
				log_admincommand $@ &
				;;
			*"$SEARCHINIT"*) 
#				echo "Init detected"
				log_initstring $@ &
				;;
			*) 
				;;
			esac
}
sm_box() {
PRECEIVE=$(ls $PLAYERFILE)
#echo "Players $PRECEIVE"
ISPLAYER=$3
#echo "Possible playername $ISPLAYER"
if [[ $PRECEIVE =~ $ISPLAYER ]]
then
	echo "player found"
	MESSAGE=${@:4}
	case "$2" in
		*"green"*) 
			as_user "screen -p 0 -S $SCREENID -X stuff $'/server_message_to info $3 \'$MESSAGE\'\n'"
		;;
		*"blue"*)
			as_user "screen -p 0 -S $SCREENID -X stuff $'/server_message_to warning $3 \'$MESSAGE\'\n'"
		;;
		*"red"*) 
			as_user "screen -p 0 -S $SCREENID -X stuff $'/server_message_to error $3 \'$MESSAGE\'\n'"
		;;
		*) 
		;;
	esac
else
	echo "No player found"
	MESSAGE=${@:3}
	case "$2" in
		*"green"*) 
			as_user "screen -p 0 -S $SCREENID -X stuff $'/server_message_broadcast info \'$MESSAGE\'\n'"
		;;
		*"blue"*)
			as_user "screen -p 0 -S $SCREENID -X stuff $'/server_message_broadcast warning \'$MESSAGE\'\n'"
		;;
		*"red"*) 
			as_user "screen -p 0 -S $SCREENID -X stuff $'/server_message_broadcast error \'$MESSAGE\'\n'"
		;;
		*) 
		;;
	esac
fi
}
#------------------------------Core logging functions-----------------------------------------

log_playerinfo() { 
#
#echo "$1 is the player name"
create_playerfile $1
as_user "screen -p 0 -S $SCREENID -X stuff $'/player_info $1\n'"
sleep 2
if tac /dev/shm/output$PORT.log | grep -m 1 -A 10 "Name: $1" >/dev/null
then
	OLD_IFS=$IFS
	IFS=$'\n'
#echo "Player info $1 found"
	PLAYERINFO=( $(tac /dev/shm/output$PORT.log | grep -m 1 -A 10 "Name: $1") )
	IFS=$OLD_IFS
	PNAME=$(echo ${PLAYERINFO[0]} | cut -d: -f2 | cut -d" " -f2)
#echo "Player name is $PNAME"
	PIP=$(echo ${PLAYERINFO[1]} | cut -d\/ -f2)
#echo "Player IP is $PIP"
	PCREDITS=$(echo ${PLAYERINFO[4]} | cut -d: -f2 | cut -d" " -f2)
#echo "Credits are $PCREDITS"
	PFACTION=$(echo ${PLAYERINFO[5]} | cut -d= -f2 | cut -d, -f1)
	if [ "$PFACTION" -eq "$PFACTION" ] 2>/dev/null
	then
		PFACTION=$PFACTION
	else
		PFACTION="None"
	fi
#echo "Faction id is $PFACTION"
	PSECTOR=$(echo ${PLAYERINFO[6]} | cut -d\( -f2 | cut -d\) -f1 | tr -d ' ')
#echo "Player sector is $PSECTOR"
	PLASTUPDATE=$(date +%s)
#echo "Player file last update is $PLASTUPDATE"
	as_user "sed -i 's/CurrentIP=.*/CurrentIP=$PIP/g' $PLAYERFILE/$1"
	as_user "sed -i 's/CurrentCredits=.*/CurrentCredits=$PCREDITS/g' $PLAYERFILE/$1"
	as_user "sed -i 's/PlayerFaction=.*/PlayerFaction=$PFACTION/g' $PLAYERFILE/$1"
	as_user "sed -i 's/PlayerLocation=.*/PlayerLocation=$PSECTOR/g' $PLAYERFILE/$1"
	as_user "sed -i 's/PlayerLastUpdate=.*/PlayerLastUpdate=$PLASTUPDATE/g' $PLAYERFILE/$1"
	as_user "sed -i 's/PlayerLoggedIn=.*/PlayerLoggedIn=Yes/g' $PLAYERFILE/$1"
fi
}
log_chatlogging() { 
CHATGREP=$@
if [[ ! $CHATGREP == *WARNING* ]] && [[ ! $CHATGREP == *object* ]]
then
#	echo $CHATGREP
# If the chat contains : then - This filters out other non related chat output from console
	if echo $CHATGREP | grep ":" >/dev/null
	then
# If the chat is a whisper then
		if echo $CHATGREP | grep "\[WISPER\]" >/dev/null
		then
# Set variable for the person who is whispering
			PWHISPERED=$(echo $CHATGREP | cut -d\] -f4 | cut -d: -f1 | tr -d ' ')
# Set variable for the person who is recieving whisper
			PWHISPERER=$(echo $CHATGREP | cut -d\[ -f6 | cut -d\] -f1)
			PLAYERCHAT=$(echo $CHATGREP | cut -d\] -f6-)
# Format the whisper mesage for the log
			WHISPERMESSAGE="$(date '+%b_%d_%Y_%H.%M.%S') - \($PWHISPERER\) whispered to \($PWHISPERED\) '$PLAYERCHAT'"
			as_user "echo $WHISPERMESSAGE >> $CHATLOG"
# If not a whiper then
		fi
		if echo $CHATGREP | grep Server >/dev/null
		then
#			echo "CHAT DETECTED - $CHATGREP"
# Set variable for player name
			PLAYERCHATID=$(echo $CHATGREP | cut -d\) -f2 | cut -d: -f1 | tr -d ' ')
# Set variable for what the player said
			PLAYERCHAT=$(echo $CHATGREP | cut -d":" -f2- | tr -d \' | tr -d \")
# Format the chat message to be written for the chat log
			CHATMESSAGE="$(date '+%b_%d_%Y_%H.%M.%S') - \($PLAYERCHATID\)'$PLAYERCHAT'"  
			as_user "echo $CHATMESSAGE >> $CHATLOG"	
		fi
	fi
fi
}
log_chatcommands() { 
# A big thanks to Titanmasher for his help with the Chat Commands.
#echo "This was passed to chat commands $1"
CHATGREP=$@
if [[ ! $CHATGREP == *WARNING* ]] && [[ ! $CHATGREP == *object* ]]
then
#	echo $CHATGREP
	COMMAND=$(echo $CHATGREP | cut -d" " -f4)
	if [[ "$CHATGREP" =~ "[SERVER][CHAT][WISPER]" ]]
	then
		PLAYERCHATID=$(echo $CHATGREP | rev | cut -d"]" -f2 | rev | cut -d"[" -f2)
	else
		PLAYERCHATID=$(echo $CHATGREP | cut -d: -f1 | rev | cut -d" " -f1 | rev)
	fi
	if [[ "${COMMAND:0:1}" == "!" ]]
	then
#	echo $CHATGREP
#	echo "this is the playerchatid $PLAYERCHATID"
# 				If the player does not have a log file, make one
		if [ -e $PLAYERFILE/$PLAYERCHATID ]
		then
			PLAYERFILEEXISTS=1
#		    echo "player has a playerfile"
		else
			log_playerinfo $PLAYERCHATID
		fi

#	Grab the chat command itself by looking for ! and then cutting after that       
		CCOMMAND=( $(echo $CHATGREP | cut -d! -f2-) )
#	echo "first command is ${CCOMMAND[0]} parameter 1 ${CCOMMAND[1]} parameter 2 ${CCOMMAND[2]} parameter 3 ${CCOMMAND[3]} "
#				echo "Here is the command with variables ${CCOMMAND[@]}"
# 				Get the player rank from their log file
# 				echo "looking for player rank"
		PLAYERRANK=$(grep Rank= "$PLAYERFILE/$PLAYERCHATID" | cut -d= -f2)
# 	echo "$PLAYERRANK is the player rank"
#				Find the allowed commands for the current player rank 
# 				echo "looking for allowed commands"
		ALLOWEDCOMMANDS=$(grep $PLAYERRANK $RANKCOMMANDS)
#	echo $ALLOWEDCOMMANDS
# 				Saves the command issued, player name and parameters to COMMANDANDPARAMETERS
#	Converts the command to uppercase, so lowercase commands can be used
		CCOMMAND[0]=$(echo ${CCOMMAND[0]} | tr [a-z] [A-Z])
		COMMANDANDPARAMETERS=(${CCOMMAND[0]} $PLAYERCHATID $(echo ${CCOMMAND[@]:1}))
#	echo "Here is the command and the parameters ${CCOMMAND[@]}"
#				echo "$PLAYERCHATID used the command ${COMMANDANDPARAMETERS[0]} with parameters ${COMMANDANDPARAMETERS[*]:2}"
#				Checks if the command exists. If not, sends a pm to the issuer
		function_exists "COMMAND_${COMMANDANDPARAMETERS[0]}"
		if [[ "$FUNCTIONEXISTS" == "0" ]]
		then	#		echo Exists
# Checks if the player has permission to use that command. -ALL- means they have access to all commands (Admin rank)
			if [[ "$ALLOWEDCOMMANDS" =~ "${COMMANDANDPARAMETERS[0]}" ]] || [[ "$ALLOWEDCOMMANDS" =~ "-ALL-" ]]
			then
# Echo's ALLOWED and then calls the function COMMAND_${COMMANDANDPARAMETERS[0]}
#						echo Allowed
				COMMAND_${COMMANDANDPARAMETERS[*]} &
#	 			$0 = Command name
#						$1 = playername
#						$2+ = parameter from command
			else
#			echo Disallowed
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm ${COMMANDANDPARAMETERS[1]} You do not have sufficient permission to use that command!\n'"
			fi
		else
#		echo Doesnt exist
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm ${COMMANDANDPARAMETERS[1]} Unrecognized command. Please try again or use !HELP\n'"
		fi
	fi
fi
}
log_admincommand() { 
if [[ ! $@ == *org.schema.schine.network.server.AdminLocalClient* ]] && [[ ! $@ =~ "no slot free for" ]]
then
	# Format the admin command string to be written to the admin log
	ADMINSTR="$@ $(date '+%b_%d_%Y_%H.%M.%S')"
	as_user "echo '$ADMINSTR' >> $ADMINLOG"
fi
}
log_playerlogout() { 
LOGOUTPLAYER=$(echo $@ | cut -d: -f2 | cut -d\( -f1 | tr -d ' ')
#echo "$LOGOUTPLAYER passed to playerlogout"

if [ -e $PLAYERFILE/$LOGOUTPLAYER ]
then
	PLAYERFILEEXISTS=1
#	echo "player has a playerfile"
else
	log_playerinfo $LOGOUTPLAYER
fi
# Use sed to change the playerfile PlayerLoggedIn to No
as_user "sed -i 's/PlayerLoggedIn=Yes/PlayerLoggedIn=No/g' $PLAYERFILE/$LOGOUTPLAYER"
# Echo current string and array to the guestboot as a log off
LOGOFF="$LOGOUTPLAYER logged off at $(date '+%b_%d_%Y_%H.%M.%S') server time"
as_user "echo $LOGOFF >> $GUESTBOOK"
as_user "sed -i '/$LOGOUTPLAYER/d' $ONLINELOG"
}
log_sectorchange() {
#echo "Sector change detected"
# Set the sector change sting to the current sector chang array
SCCHNGTR=$@   
# If a sector change took place with a character then
#----------------------------PLAYER---------------------------------------------
if (echo "$SCCHNGTR" | grep "[DOCKING]" >/dev/null)
then
	if (echo "$SCCHNGTR" | grep PlayerCharacter >/dev/null)
	then 
	# Set variable for player name
		PLAYERSCSOLO=$(echo "$SCCHNGTR" | cut -d_ -f3- | cut -d\) -f1)
		if [[ ! -f $PLAYERFILE/$PLAYERSCSOLO ]]
		then
			log_playerinfo $PLAYERSCSOLO
		fi	
#		echo "This is the player that changed sectors $PLAYERSCSOLO"
	# Set variable for new sector
		PLAYERSCSOLOCHANGE=$(echo "$SCCHNGTR" | cut -d\( -f8 | cut -d\) -f1 | tr -d ' ')      
#		echo "This is the new sector $PLAYERSCSOLOCHANGE"
	# Find the last sector for the player from player.log
		PLOLDSCOTYPE=$(grep PlayerControllingType $PLAYERFILE/$PLAYERSCSOLO | cut -d= -f2)
		PLOLDSCCHANGE=$(grep PlayerLocation $PLAYERFILE/$PLAYERSCSOLO | cut -d= -f2 | tr -d ' ')
#		echo "This was the last object player was in $PLOLDSCOTYPE"
		as_user "sed -i 's/PlayerLocation=$PLOLDSCCHANGE/PlayerLocation=$PLAYERSCSOLOCHANGE/g' $PLAYERFILE/$PLAYERSCSOLO"
	#----------------------------SHIP---------------------------------------------
	# If there is a sector change with a ship
	elif (echo "$SCCHNGTR" | grep Ship >/dev/null)
	then
	#	echo "Player change sector with ship"
	# Player name from the change sector string
		PLAYERSCSHIP=$(echo "$SCCHNGTR" | cut -d[ -f4 | cut -d\; -f1 | rev | cut -d" " -f2-  | rev)
	#	echo "This is player $PLAYERSCSHIP"
		if [[ ! -f $PLAYERFILE/$PLAYERSCSHIP ]]
		then
			log_playerinfo $PLAYERSCSHIP
		fi
		PLAYERSCSHIPCHANGE=$(echo "$SCCHNGTR" | cut -d\( -f7 | cut -d\) -f1 | tr -d ' ')
	#	echo "This is the new sector $PLAYERSCSHIPCHANGE"
	# Ship name for the change sector string
		OLD_IFS=$IFS
		IFS=$'\n'
		SHIPSC=$(echo "$SCCHNGTR" | cut -d\[ -f3 | cut -d\] -f1) 
	#	echo "This is the ship that is changing sectors $SHIPSC"
		IFS=$OLD_IFS
	# New sector changed to from the sector sting
		OLDSHIPSC=$(grep "PlayerLocation" $PLAYERFILE/$PLAYERSCSHIP | cut -d= -f2 | tr -d ' ')
	#	echo "This is the old sector $OLDSHIPSC"
		as_user "sed -i 's/PlayerLocation=$OLDSHIPSC/PlayerLocation=$PLAYERSCSHIPCHANGE/g' $PLAYERFILE/$PLAYERSCSHIP"
	#----------------------------STATION---------------------------------------------
	# If there is a sector change with a station
	elif (echo "$SCCHNGTR" | grep SpaceStation >/dev/null)
	then
	#	echo "Player change sector with SpaceStation"
	# Player name from the change sector string
		PLAYERSCSTATION=$(echo "$SCCHNGTR" | cut -d[ -f4 | cut -d\; -f1 | rev | cut -d" " -f2-  | rev)
	#	echo "This is player $PLAYERSCSTATION"
		if [[ ! -f $PLAYERFILE/$PLAYERSCSTATION ]]
		then
			log_playerinfo $PLAYERSCSTATION
		fi
		PLAYERSCSTATIONCHANGE=$(echo "$SCCHNGTR" | cut -d\( -f7 | cut -d\) -f1 | tr -d ' ')
	#	echo "This is the new sector $PLAYERSCSTATIONCHANGE"
	# Ship name for the change sector string
		OLD_IFS=$IFS
		IFS=$'\n'
		STATIONSC=$(echo "$SCCHNGTR" | cut -d_ -f3,4 | cut -d\( -f1) 
	#	echo "This is the station that is changing sectors $STATIONSC"
		IFS=$OLD_IFS
	# New sector changed to from the sector sting
		OLDSTATIONSC=$(grep "PlayerLocation" $PLAYERFILE/$PLAYERSCSTATION | cut -d= -f2 | tr -d ' ')
	#	echo "This is the old sector $OLDSTATIONSC"
		as_user "sed -i 's/PlayerLocation=$OLDSTATIONSC/PlayerLocation=$PLAYERSCSTATIONCHANGE/g' $PLAYERFILE/$PLAYERSCSTATION"
	#----------------------------PLANET---------------------------------------------
	# If there is a sector change with a planet
	elif (echo "$SCCHNGTR" | grep Planet >/dev/null)
	then
	#	echo "Player change sector with Planet"
	# Player name from the change sector string
		PLAYERSCPLANET=$(echo "$SCCHNGTR" | cut -d[ -f4 | cut -d\; -f1 | rev | cut -d" " -f2-  | rev)
	#	echo "This is player $PLAYERSCPLANET"
		if [[ ! -f $PLAYERFILE/$PLAYERSCPLANET ]]
		then
			log_playerinfo $PLAYERSCPLANET
		fi
		PLAYERSCPLANETCHANGE=$(echo "$SCCHNGTR" | cut -d\( -f7 | cut -d\) -f1 | tr -d ' ')
	#	echo "This is the new sector $PLAYERSCPLANETCHANGE"
	# Ship name for the change sector string
		OLD_IFS=$IFS
		IFS=$'\n'
		PLANETSC=$(echo "$SCCHNGTR" | cut -d\( -f2 | cut -d\) -f1) 
	#	echo "This is the planet that is changing sectors $PLANETSC"
		IFS=$OLD_IFS
	# New sector changed to from the sector sting
		OLDPLANETSC=$(grep "PlayerLocation" $PLAYERFILE/$PLAYERSCPLANET | cut -d= -f2 | tr -d ' ')
	#	echo "This is the old sector $OLDPLANETSC"
		as_user "sed -i 's/PlayerLocation=$OLDPLANETSC/PlayerLocation=$PLAYERSCPLANETCHANGE/g' $PLAYERFILE/$PLAYERSCPLANET"
	fi
fi
}
log_on_login() { 
LOGINPLAYER=$(echo $@ | cut -d: -f2 | cut -d" " -f2)
#echo "$LOGINPLAYER logged in"
create_playerfile $LOGINPLAYER
DATE=$(date '+%b_%d_%Y_%H.%M.%S')
as_user "sed -i 's/JustLoggedIn=.*/JustLoggedIn=Yes/g' $PLAYERFILE/$LOGINPLAYER"
as_user "sed -i 's/ChatCount=.*/ChatCount=0/g' $PLAYERFILE/$LOGINPLAYER"
as_user "sed -i 's/SwearCount=.*/SwearCount=0/g' $PLAYERFILE/$LOGINPLAYER"
as_user "sed -i 's/PlayerLastLogin=.*/PlayerLastLogin=$DATE/g' $PLAYERFILE/$LOGINPLAYER"
LOGON="$LOGINPLAYER logged on at $(date '+%b_%d_%Y_%H.%M.%S') server time"
as_user "echo $LOGON >> $GUESTBOOK"
as_user "echo $LOGINPLAYER >> $ONLINELOG"
}
log_initstring() {
INITPLAYER=$(echo $@ | cut -d\[ -f3 | cut -d\; -f1 | tr -d " ")
sleep 0.5
log_playerinfo $INITPLAYER
if grep -q "JustLoggedIn=Yes" $PLAYERFILE/$INITPLAYER 
then
	LOGINMESSAGE="Welcome to the server $INITPLAYER! Type !HELP for chat commands"
	# A chat message that is displayed whenever a player logs in
	as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $INITPLAYER $LOGINMESSAGE\n'"
	as_user "sed -i 's/JustLoggedIn=.*/JustLoggedIn=No/g' $PLAYERFILE/$INITPLAYER"
fi
}

#------------------------------Game mechanics-----------------------------------------

randomhelptips(){
create_tipfile
while [ -e /proc/$SM_LOG_PID ]
do
	RANDLINE=$(($RANDOM % $(wc -l < "$TIPFILE") + 1))
	as_user "screen -p 0 -S $SCREENID -X stuff $'/chat $(sed -n ${RANDLINE}p $TIPFILE)\n'"
	sleep $TIPINTERVAL
done
}

autovoteretrieval(){ 
if [[ "$SERVERKEY" == "00000000000000000000" ]]
then
	NOKEY=YES
#	echo "No server key set for voting rewards"
else
	KEYURL="http://starmade-servers.com/api/?object=servers&element=voters&key=$SERVERKEY&month=current&format=xml"
	while [ -e /proc/$SM_LOG_PID ]
	do
		if [ "$(ls -A $PLAYERFILE)" ]
		then
			ALLVOTES=$(wget -q -O - $KEYURL)
			for PLAYER in $PLAYERFILE/*
			do
				PLAYER=$(echo $PLAYER | rev | cut -d"/" -f1 | rev )
				TOTALVOTES=$(echo $ALLVOTES | tr " " "\n" | grep -A1 ">$PLAYER<" | tr "\n" " " | cut -d">" -f4 | cut -d"<" -f1)
				VOTINGPOINTS=$(grep "VotingPoints=" $PLAYERFILE/$PLAYER | cut -d= -f2 | tr -d " " )
				CURRENTVOTES=$(grep "CurrentVotes=" $PLAYERFILE/$PLAYER | cut -d= -f2 | tr -d " " )
				if [[ ! -z "$TOTALVOTES" ]]
				then
					if [ $TOTALVOTES -ge $CURRENTVOTES ]
					then
						ADDVOTES=$(($TOTALVOTES-$CURRENTVOTES))
					else
						ADDVOTES=$TOTALVOTES
					fi
					VOTESSAVED=$(($VOTINGPOINTS+$ADDVOTES))
					as_user "sed -i 's/VotingPoints=.*/VotingPoints=$VOTESSAVED/g' $PLAYERFILE/$PLAYER"
					as_user "sed -i 's/CurrentVotes=.*/CurrentVotes=$TOTALVOTES/g' $PLAYERFILE/$PLAYER"
					if [ $ADDVOTES -gt 0 ]
					then
						as_user "screen -p 0 -S $SCREENID -X stuff $'/chat $PLAYER just got $ADDVOTES point(s) for voting! You can get voting points too by going to starmade-servers.com!\n'"
					fi
				fi
			done
		fi
		sleep $VOTECHECKDELAY
	done
fi
}
function_exists(){
declare -f -F $1 > /dev/null 2>&1
FUNCTIONEXISTS=$?
}

#---------------------------Files Daemon Writes and Updates---------------------------------------------

write_factionfile() { 
CREATEFACTION="cat > $FACTIONFILE/$1 <<_EOF_
CreditsInBank=0
_EOF_"
as_user "$CREATEFACTION"
}

write_configpath() {
CONFIGCREATE="cat > $CONFIGPATH <<_EOF_
#  Settings below can all be custom tailored to any setup.
#  Username is your user on the server that runs starmade
#  Backupname is the name you want your backup file to have
#  Service is the name of your Starmade jar file 
#  Backup is the path you want to move you backups to
#  Starterpath is where you starter file is located.  Starmade folder will be located in this directory
#  Maxmemory controls the total amount Java can use.  It is the -xmx variable in Java
#  Minmemory is the inital amounr of memory to use.  It is the -xms variable in Java
#  Port is the port that Starmade will use.  Set to 4242 by default.
#  Logging is for turning on or off with a YES or a NO
#  Daemon Path is only used if you are going to screen log
#  Server key is for the rewards and voting function and is setup for http://starmade-servers.com/
HASH=$CURRENTHASH
SERVICE='StarMade.jar' #The name of the .jar file to be run
USERNAME="$USERNAME" #Your login name
BACKUP='/home/$USERNAME/starbackup' #The location where all backups created are saved
BACKUPNAME='Star_Backup_' #Name of the backups
MAXMEMORY=512m #Java setting. Max memory assigned to the server
MINMEMORY=256m #Java setting. Min memory assigned to the server
PORT=4242 #The port the server will run on
SCREENID=smserver #Name of the screen the server will be run on
SCREENLOG=smlog #Name of the screen logging will be run on
LOGGING=YES #Determines if logging will be active (YES/NO))
SERVERKEY="00000000000000000000" #Server key found at starmade-servers.com (used for voting rewards)
#------------------------Logging files----------------------------------------------------------------------------
RANKCOMMANDS=$STARTERPATH/logs/rankcommands.log #The file that contains all the commands each rank is allowed to use
CHATLOG=$STARTERPATH/logs/chat.log #The file that contains a record of all chat messages sent
BOUNTYLOG=$STARTERPATH/logs/bounty.log #The file that contains all bounty records
PLAYERFILE=$STARTERPATH/playerfiles #The directory that contains all the individual player files which store player information
ADMINLOG=$STARTERPATH/logs/admin.log #The file with a record of all admin commands issued
GUESTBOOK=$STARTERPATH/logs/guestbook.log #The file with a record of all the logouts on the server
BANKLOG=$STARTERPATH/logs/bank.log #The file that contains all transactions made on the server
ONLINELOG=$STARTERPATH/logs/online.log #The file that contains the list of currently online players
TIPFILE=$STARTERPATH/logs/tips.txt #The file that contains random tips that will be told to players
FACTIONFILE=$STARTERPATH/factionfiles #The folder that contains individual faction files
#------------------------Game settings----------------------------------------------------------------------------
VOTECHECKDELAY=10 #The time in seconds between each check of starmade-servers.org
CREDITSPERVOTE=1000000 # The number of credits a player gets per voting point.
TIPINTERVAL=600 #Number of seconds between each tip being shown
STARTINGRANK=Ensign #The initial rank players recieve when they log in for the first time. Can be edited.
_EOF_"
as_user "$CONFIGCREATE"
}
write_playerfile() {
PLAYERCREATE="cat > $PLAYERFILE/$1 <<_EOF_
Rank=$STARTINGRANK
CreditsInBank=0
VotingPoints=0
CurrentVotes=0
Bounty=0
BountyPlaced=0
CurrentIP=0.0.0.0
CurrentCredits=0
PlayerFaction=None
PlayerLocation=2,2,2
PlayerLastLogin=0
PlayerLastCore=0
PlayerLastUpdate=0
PlayerLastKilled=None
PlayerKilledBy=None
PlayerKilledtime=0
PlayerLoggedIn=No
ChatCount=0
JustLoggedIn=No
_EOF_"
as_user "$PLAYERCREATE"
}
write_rankcommands() {
CREATERANK="cat > $RANKCOMMANDS <<_EOF_
Ensign POSTBOUNTY LISTBOUNTY COLLECTBOUNTY DEPOSIT WITHDRAW TRANSFER BALANCE RANKME RANKLIST RANKCOMMAND VOTEBALANCE PING HELP CORE CLEAR FDEPOSIT FWITHDRAW FBALANCE
Lieutenant POSTBOUNTY LISTBOUNTY COLLECTBOUNTY DEPOSIT WITHDRAW TRANSFER BALANCE RANKME RANKLIST RANKCOMMAND VOTEBALANCE PING HELP CORE SEARCH CLEAR FDEPOSIT FWITHDRAW FBALANCE
Commander POSTBOUNTY LISTBOUNTY COLLECTBOUNTY DEPOSIT WITHDRAW TRANSFER BALANCE RANKME RANKLIST RANKCOMMAND VOTEBALANCE PING HELP CORE SEARCH CLEAR FDEPOSIT FWITHDRAW FBALANCE
Captain POSTBOUNTY LISTBOUNTY COLLECTBOUNTY DEPOSIT WITHDRAW TRANSFER BALANCE RANKME RANKLIST RANKCOMMAND VOTEBALANCE PING HELP CORE SEARCH CLEAR FDEPOSIT FWITHDRAW FBALANCE
Admiral POSTBOUNTY LISTBOUNTY COLLECTBOUNTY DEPOSIT WITHDRAW TRANSFER BALANCE RANKME RANKLIST RANKCOMMAND VOTEBALANCE PING HELP CORE SEARCH CLEAR RANKSET RANKUSER MYDETAILS THREADDUMP GIVEMETA FDEPOSIT FWITHDRAW FBALANCE
Admin -ALL-
_EOF_"
as_user "$CREATERANK"
}
write_tipfile() {
CREATETIP="cat > $TIPFILE <<_EOF_
!HELP is your friend! If you are stuck on a command, use !HELP <Command>
Ever wanted to be rewarded for voting for the server? Vote now at starmade-servers.org to get voting points!
Got too much money? Store some in your bank account with !DEPOSIT
Need to get some money? Take some out of your bank account with !WITHDRAW
Stuck in the middle of nowhere but dont want to suicide? Try !CORE
Want to secretly use a command? Try using a command inside a PM to yourself!
_EOF_"
as_user "$CREATETIP"
}
create_configpath() {
if [ ! -e $CONFIGPATH ]
then
	write_configpath
fi
}
create_tipfile(){
if [ ! -e $TIPFILE ]
then
	write_tipfile
fi
}
create_playerfile(){
if [[ ! -f $PLAYERFILE/$1 ]]
then
#	echo "File not found"
	write_playerfile $1
fi
}
create_factionfile(){
if [[ ! -f $FACTIONFILE/$1 ]]
then
#	echo "File not found"
	write_factionfile $1
fi
}
create_rankscommands(){
if [ ! -e $RANKCOMMANDS ]
then
	write_rankcommands
fi
}
update_file() {
#echo "Starting Update"
#echo "$1 is the write function to update the old config filename"
#echo "$2 is the name of the specific file for functions like playerfile or factionfile"
# Grab first occurrence of value from the Daemon file itself to be used to determine correct path
DLINE=$(grep -n -m 1 $1 $DAEMONPATH | cut -d : -f 1)
#echo "This is the starting line for the write function $DLINE"
let DLINE++
EXTRACT=$(sed -n "${DLINE}p" $DAEMONPATH)
# echo "Here is the second line of write funtion $EXTRACT"
if [ "$#" -eq "2" ]
then
	PATHUPDATEFILE=$(echo $EXTRACT | cut -d$ -f2- | cut -d/  -f1)
#	echo "Extraction from Daemon $PATHUPDATEFILE"
	PATHUPDATEFILE=${!PATHUPDATEFILE}/$2
#	echo "modified directory $PATHUPDATEFILE"
else
	PATHUPDATEFILE=$(echo $EXTRACT | cut -d$ -f2- | cut -d" " -f1)
#	echo "This is what was extracted from the Daemon $PATHUPDATEFILE"
# Set the path to what the source of the config file value is
	PATHUPDATEFILE=${!PATHUPDATEFILE}
	cp $PATHUPDATEFILE $PATHUPDATEFILE.old
fi
# echo "This is the actual path to the file to be updated $PATHUPDATEFILE"
#This is how you would compare files for future work ARRAY=( $(grep -n -Fxvf test1 test2) )
OLD_IFS=$IFS
IFS=$'\n'
# Create an array of the old file
OLDFILESTRING=( $(cat $PATHUPDATEFILE) )
as_user "rm $PATHUPDATEFILE"
# $1 is the write file function for the file being updated and if $2 is set it will use specific file
$1 $2
# Put the newly written file into an array
NEWFILESTRING=( $(cat $PATHUPDATEFILE) )
IFS=$OLD_IFS
NEWARRAY=0
as_user "rm $PATHUPDATEFILE"
# The following rewrites the config file and preserves values from the old configuration file 
while [ -n "${NEWFILESTRING[$NEWARRAY]+set}" ]
do
	NEWSTR=${NEWFILESTRING[$NEWARRAY]}
	OLDARRAY=0
	WRITESTRING=$NEWSTR
	while [ -n "${OLDFILESTRING[$OLDARRAY]+set}" ]
	do
	OLDSTR=${OLDFILESTRING[$OLDARRAY]}
# If a = is detected grab the value to the right of = and then overwrite the new value
	if [[ $OLDSTR == *=* ]]
	then
		NEWVAR=${NEWSTR%%=*}
#		echo "Here is the NEWVAR $NEWVAR"
		NEWVAL=${NEWSTR#*=}
#		echo "Here is the NEWVAL $NEWVAL"
		OLDVAR=${OLDSTR%%=*}
#		echo "Here is the OLDVAR $OLDVAR"
		OLDVAL=${OLDSTR#*=}
#		echo "Here is the OLDVAL $OLDVAL"
		if [[ "$OLDVAR" == "$NEWVAR" ]]
		then
#			echo "Matched oldvar $OLDVAR to newvar $NEWVAR"
			WRITESTRING=${NEWSTR/$NEWVAL/$OLDVAL} 
		fi
	fi
	let OLDARRAY++
	done
#	echo "Here is the writestring $WRITESTRING"	
	as_user "cat <<EOF >> $PATHUPDATEFILE
$WRITESTRING
EOF"
let NEWARRAY++
done
}
update_daemon() {
update_file write_configpath
update_file write_tipfile
update_file write_rankcommands
PUPDATE=( $(ls $PLAYERFILE) )
PARRAY=0
while [ -n "${PUPDATE[$PARRAY]+set}" ] 
do
update_file write_playerfile ${PUPDATE[$PARRAY]}
#echo "${PUPDATE[$PARRAY]} file is being updated"
let PARRAY++
done
FUPDATE=( $(ls $FACTIONFILE) )
FARRAY=0
while [ -n "${FUPDATE[$FARRAY]+set}" ] 
do
update_file write_factionfile ${FUPDATE[$FARRAY]}
#echo "${FUPDATE[$FARRAY]} file is being updated"
let FARRAY++
done
CURRENTHASH=$(md5sum $DAEMONPATH |  cut -d" " -f1 | tr -d ' ')
# Update the HASH
as_user "sed -i 's/HASH=.*/HASH=$CURRENTHASH/g' $CONFIGPATH"
}

#---------------------------Chat Commands---------------------------------------------

#Example Command
#In the command system, $1 = Playername , $2 = parameter 1 , $3 = parameter 2 , ect
#e.g if Titansmasher types "!FOLD 9 8 7" then $1 = Titansmasher , $2 = 9 , $3 = 8 , $4 = 7
#function COMMAND_EXAMPLE(){
##Description told to user when !HELP EXAMPLE is used (This line must be a comment)
##USAGE: How to use the commands parameters (This line must be a comment)
#	if [ "$#" -ne "NumberOfParameters+1" ]
#	then
#		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 ParameterErrorMessage\n'"
#	else
#		Function workings
#	fi
#}

#Bounty Commands
function COMMAND_POSTBOUNTY(){ 
#Places a bounty on the player specified, by taking the specified amount of credits from your account.
#USAGE: !POSTBOUNTY <Player> <Amount>
if [ "$#" -ne "3" ]
then
	as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !POSTBOUNTY <player> <amount>\n'"
else
#	echo "$1 wants to place a $3 credit bounty on $2"
	source $PLAYERFILE/$1
	BALANCECREDITS=$CreditsInBank
#	echo "Current bank credits are $BALANCECREDITS"
	if [ "$1" = "$2" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC COMMAND - You cannot post a bounty on yourself\n'"
	 else
		if ! test "$3" -gt 0 2> /dev/null
		then
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - You must put in a positive number\n'"
		else
			if [ -e $PLAYERFILE/$2 ] >/dev/null
			then
				if [ "$3" -le "$BALANCECREDITS" ]
				then
					source $PLAYERFILE/$2
					OLDBOUNTY=$Bounty
#					echo "The old bounty is $OLDBOUNTY"
#					echo "Current bounty found"
					CURRENTBOUNTY=$(( $OLDBOUNTY + $3 ))
#					echo "The current new bounty will be $CURRENTBOUNTY"
					NEWBALANCE=$(( $BALANCECREDITS - $3 ))
					if [ "$OLDBOUNTY" -eq "0" ]
					then
						as_user "sed -i 's/Bounty=.*/Bounty=$CURRENTBOUNTY/g' $PLAYERFILE/$2"
						as_user "sed -i 's/BountyPlaced=.*/BountyPlaced=$(date +%s)/g' $PLAYERFILE/$2"
						as_user "sed -i 's/CreditsInBank=.*/CreditsInBank=$NEWBALANCE/g' $PLAYERFILE/$1"
						as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC COMMAND - You have placed a bounty of $3 on $2\n'"
					else
						as_user "sed -i 's/Bounty=.*/Bounty=$CURRENTBOUNTY/g' $PLAYERFILE/$2"
						as_user "sed -i 's/CreditsInBank=.*/CreditsInBank=$NEWBALANCE/g' $PLAYERFILE/$1"
						as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC COMMAND - You have placed a bounty of $3 on $2\n'"
				
					fi
				else 
					as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - Not enough credits in your bank account. Please use !DEPOSIT <Amount>\n'"
				fi	
			else
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC COMMAND - This person does not exist\n'"
			fi
		fi
	fi	
fi
}
function COMMAND_LISTBOUNTY(){ 
#Lists all players with bounties, and how much they are worth
#USAGE: !LISTBOUNTY
if [ "$#" -ne "1" ]
then
	as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !LISTBOUNTY\n'"
else
	BOUNTYLIST=( $(ls $PLAYERFILE) )
#	echo "here is the playefile list ${BOUNTYLIST[@]}"
	BARRAY=0
	while [ -n "${BOUNTYLIST[$BARRAY]+set}" ] 
	do
		BOUNTYNAME=${BOUNTYLIST[$BARRAY]}
#		echo "Current playername $BOUNTYNAME"
		source $PLAYERFILE/$BOUNTYNAME
#		echo "Current bounty for player $Bounty"
		BOUNTYTOTAL=0
		if [ "$Bounty" -gt 0 ]
		then
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 $BOUNTYNAME - $Bounty credits\n'"
			let BOUNTYTOTAL++
		fi
		let BARRAY++
	done
	if [ "$BOUNTYTOTAL" -eq "0" ]	
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 No bounties detected\n'"
	fi
fi
}

#Bank Commands
function COMMAND_DEPOSIT(){ 
#Deposits money into your server account from your player
#USAGE: !DEPOSIT <Amount>
	if [ "$#" -ne "2" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !DEPOSIT <Amount>\n'"
	else
# Check to make sure a posistive amount was entered
		if ! test "$2" -gt 0 2> /dev/null
		then
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - You must put in a positive number\n'"
		else 
# Run playerinfo command to update playerfile and get the current player credits
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTICE BANK - Connecting to servers\n'"
			log_playerinfo $1
#			as_user "screen -p 0 -S $SCREENID -X stuff $'/player_info $1\n'"
#			echo "sent message to counsel, now sleeping"
# Sleep is added here to give the console a little bit to respond

# Check the playerfile to see if it was updated recently by comparing it to the current time
			CURRENTTIME=$(date +%s)
#			echo "Current time $CURRENTTIME"
			OLDTIME=$(grep PlayerLastUpdate $PLAYERFILE/$1 | cut -d= -f2- |  tr -d ' ')
#			echo "Old time from playerfile $OLDTIME"
			ADJUSTEDTIME=$(( $CURRENTTIME - 10 ))
#			echo "Adjusted time to remove 10 seconds $ADJUSTEDTIME"
			if [ "$OLDTIME" -ge "$ADJUSTEDTIME" ]
			then
				BALANCECREDITS=$(grep CreditsInBank $PLAYERFILE/$1 | cut -d= -f2- |  tr -d ' ')
#				echo $BALANCECREDITS
				CREDITSTOTAL=$(grep CurrentCredits $PLAYERFILE/$1 | cut -d= -f2- |  tr -d ' ')  
#				echo "Credits in log $CREDITTOTAL"
#				echo "Total credits are $CREDITSTOTAL on person and $BALANCECREDITS in bank"
#				echo "Credits to be deposited $2 "
				if [ "$CREDITSTOTAL" -ge "$2" ]
				then 
#					echo "enough money detected"
					NEWBALANCE=$(( $2 + $BALANCECREDITS ))
					NEWCREDITS=$(( $CREDITSTOTAL - $2 ))
#					echo "new bank balance is $NEWBALANCE"
					as_user "sed -i 's/CurrentCredits=$CREDITSTOTAL/CurrentCredits=$NEWCREDITS/g' $PLAYERFILE/$1"
					as_user "sed -i 's/CreditsInBank=$BALANCECREDITS/CreditsInBank=$NEWBALANCE/g' $PLAYERFILE/$1"
					#					as_user "sed -i '4s/.*/CreditsInBank=$NEWBALANCE/g' $PLAYERFILE/$1"
					as_user "screen -p 0 -S $SCREENID -X stuff $'/give_credits $1 -$2\n'"
					as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALATIC BANK You successfully deposited $2 credits\n'"
					as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALATIC BANK Your balance is now $NEWBALANCE\n'"
					as_user "echo '$1 deposited $2' >> $BANKLOG"
				else
					as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALATIC BANK Insufficient money\n'"
#					echo "not enough money"
				fi
			else
#				echo "Time difference to great, playerfile not updated recently"
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Connecting to GALACTICE BANK servers failed\n'"
			fi
		fi
	fi	

#
}
function COMMAND_WITHDRAW(){ 
#Takes money out of your server account and gives it to your player
#USAGE: !WITHDRAW <Amount>
#	echo "Withdraw command"
	if [ "$#" -ne "2" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !WITHDRAW <Amount>\n'"
	else

		if ! test "$2" -gt 0 2> /dev/null
		then
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - You must put in a positive number\n'"
		else
#			echo "Withdraw $2"
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - Connecting to servers\n'"
			BALANCECREDITS=$(grep CreditsInBank $PLAYERFILE/$1 | cut -d= -f2 | tr -d ' ')
#			echo "bank balance is $BALANCECREDITS"
			if [ "$2" -le "$BALANCECREDITS" ]
			then
				NEWBALANCE=$(( $BALANCECREDITS - $2 ))
#				echo "new balance for bank account is $NEWBALANCE"
				as_user "screen -p 0 -S $SCREENID -X stuff $'/give_credits $1 $2\n'"
				as_user "sed -i 's/CreditsInBank=$BALANCECREDITS/CreditsInBank=$NEWBALANCE/g' $PLAYERFILE/$1"
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALATIC BANK You successfully withdrawn $2 credits\n'"
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALATIC BANK Your balance is $NEWBALANCE credits\n'"
				as_user "echo '$1 witdrew $2' >> $BANKLOG"
			else
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - You have insufficient funds\n'"
			fi
		fi
	fi
}
function COMMAND_TRANSFER(){ 
#Sends money from your bank account to another players account
#USAGE: !TRANSFER <Player> <Amount>
	if [ "$#" -ne "3" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !TRANSFER <Player> <Amount>\n'"
	else
#	echo "Transfer $1 a total of $3 credits"
	if ! test "$3" -gt 0 2> /dev/null
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - You must put in a positive number\n'"
	else 
		if [ -e $PLAYERFILE/$2 ] >/dev/null 
		then
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - Connecting to servers\n'"
			BALANCECREDITS=$(grep CreditsInBank $PLAYERFILE/$1 | cut -d= -f2 | tr -d ' ')
#			echo "Player transferring has $BALANCECREDITS in account"
			if [ "$3" -lt "$BALANCECREDITS" ]
			then
				TRANSFERBALANCE=$(grep CreditsInBank $PLAYERFILE/$2 | cut -d= -f2 | tr -d ' ')
#				echo "Player receiving has $TRANSFERBALANCE in his account"
				NEWBALANCETO=$(( $3 + $TRANSFERBALANCE ))
				NEWBALANCEFROM=$(( $BALANCECREDITS - $3 ))
#				echo "Changing $1 account to $NEWBALANCEFROM and $2 account to $NEWBALANCETO"
				as_user "sed -i 's/CreditsInBank=$BALANCECREDITS/CreditsInBank=$NEWBALANCEFROM/g' $PLAYERFILE/$1"
				as_user "sed -i 's/CreditsInBank=$TRANSFERBALANCE/CreditsInBank=$NEWBALANCETO/g' $PLAYERFILE/$2"
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALATIC BANK - You sent $3 credits to $2\n'"
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALATIC BANK - Your balance is now $NEWBALANCEFROM\n'"
				as_user "echo '$1 transferred to $2 in the amount of $3' >> $BANKLOG"
			else
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - Not enough credits\n'"
			fi
		else 
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - No account found\n'"
		fi
	fi
fi
}
function COMMAND_BALANCE(){
#Tells the player how much money is stored in their server account
#USAGE: !BALANCE
	if [ "$#" -ne "1" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !BALANCE\n'"
	else
	BALANCECREDITS=$(grep CreditsInBank $PLAYERFILE/$1 | cut -d= -f2 | tr -d ' ')
	as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - You have $BALANCECREDITS credits\n'"
	fi
}
function COMMAND_FDEPOSIT(){
#Allows you to deposit credits into a shared faction bank account
#USAGE: !FDEPOSIT <Amount>
	if [ "$#" -ne "2" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !FACTIONDEPOSIT <Amount>\n'"
	else
		if [ "$2" -gt 0 ] 2>/dev/null
		then
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Connecting to GALACTICE BANK servers\n'"
			log_playerinfo $1
			FACTION=$(grep "PlayerFaction=" $PLAYERFILE/$1 | cut -d= -f2)
			if [ ! $FACTION = "None" ]
			then
				create_factionfile $FACTION
				CURRENTTIME=$(date +%s)
#				echo "Current time $CURRENTTIME"
				OLDTIME=$(grep PlayerLastUpdate $PLAYERFILE/$1 | cut -d= -f2- |  tr -d ' ')
#				echo "Old time from playerfile $OLDTIME"
				ADJUSTEDTIME=$(( $CURRENTTIME - 10 ))
#				echo "Adjusted time to remove 10 seconds $ADJUSTEDTIME"
				if [ "$OLDTIME" -ge "$ADJUSTEDTIME" ]
				then
					BALANCECREDITS=$(grep CreditsInBank $FACTIONFILE/$FACTION | cut -d= -f2- |  tr -d ' ')
#					echo $BALANCECREDITS
					CREDITSTOTAL=$(grep CurrentCredits $PLAYERFILE/$1 | cut -d= -f2- |  tr -d ' ')  
#					echo "Credits in log $CREDITTOTAL"
#					echo "Total credits are $CREDITSTOTAL on person and $BALANCECREDITS in bank"
#					echo "Credits to be deposited $2 "
					if [ "$CREDITSTOTAL" -ge "$2" ]
					then 
#						echo "enough money detected"
						NEWBALANCE=$(( $2 + $BALANCECREDITS ))
						NEWCREDITS=$(( $CREDITSTOTAL - $2 ))
#						echo "new bank balance is $NEWBALANCE"
						as_user "sed -i 's/CurrentCredits=.*/CurrentCredits=$NEWCREDITS/g' $PLAYERFILE/$1"
						as_user "sed -i 's/CreditsInBank=.*/CreditsInBank=$NEWBALANCE/g' $FACTIONFILE/$FACTION"
#						as_user "sed -i '4s/.*/CreditsInBank=$NEWBALANCE/g' $PLAYERFILE/$1"
						as_user "screen -p 0 -S $SCREENID -X stuff $'/give_credits $1 -$2\n'"
						as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALATIC BANK You successfully deposited $2 credits\n'"
						as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALATIC BANK Your factions balance is now $NEWBALANCE\n'"
						as_user "echo '$1 deposited $2 into $FACTION bank account' >> $BANKLOG"
					else
						as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALATIC BANK Insufficient money\n'"
#						echo "not enough money"
					fi
				else
#					echo "Time difference to great, playerfile not updated recently"
					as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Connecting to GALACTICE BANK servers failed\n'"
				fi
			else
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTICE BANK - You are not in a faction\n'"
			fi
		else
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Please enter a positive whole number\n'"
		fi
	fi
}
function COMMAND_FWITHDRAW(){
#Allows you to withdraw from a shared faction account
#USAGE: !FWITHDRAW <Amount>
	if [ "$#" -ne "2" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !FACTIONWITHDRAW <Amount>\n'"
	else
		if [ "$2" -gt 0 ] 2>/dev/null
		then
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTICE BANK - Connecting to servers\n'"
			log_playerinfo $1
			FACTION=$(grep "PlayerFaction=" $PLAYERFILE/$1 | cut -d= -f2)
			if [ ! $FACTION = "None" ]
			then
				create_factionfile $FACTION
				BALANCECREDITS=$(grep CreditsInBank $FACTIONFILE/$FACTION | cut -d= -f2 | tr -d ' ')
#				echo "bank balance is $BALANCECREDITS"
				if [ "$2" -le "$BALANCECREDITS" ]
				then
					NEWBALANCE=$(( $BALANCECREDITS - $2 ))
#					echo "new balance for bank account is $NEWBALANCE"
					as_user "screen -p 0 -S $SCREENID -X stuff $'/give_credits $1 $2\n'"
					as_user "sed -i 's/CreditsInBank=$BALANCECREDITS/CreditsInBank=$NEWBALANCE/g' $FACTIONFILE/$FACTION"
					as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALATIC BANK You successfully withdrawn $2 credits\n'"
					as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALATIC BANK The factions balance is $NEWBALANCE credits\n'"
					as_user "echo '$1 witdrew $2 from $FACTION' >> $BANKLOG"
				else
					as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - Your faction has insufficent funds\n'"
				fi
			else
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - You are not in a faction\n'"
			fi
		else
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Please enter positive whole numbers only.\n'"
		fi
	fi

}
function COMMAND_FBALANCE(){
#Allows you to see how many credits are in a shared faction account
#USAGE: !FBALANCE
	if [ "$#" -ne "1" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !BALANCE\n'"
	else
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - Connecting to servers\n'"
		log_playerinfo $1
		FACTION=$(grep "PlayerFaction" $PLAYERFILE/$1 | cut -d= -f2)
		if [ ! $FACTION = "None" ]
		then
			BALANCECREDITS=$(grep CreditsInBank $FACTIONFILE/$FACTION | cut -d= -f2 | tr -d ' ')
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - Your faction has $BALANCECREDITS credits\n'"
		else
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - You are not in a faction\n'"
		fi
	fi
}
function COMMAND_VOTEEXCHANGE(){
#Converts the specified number of voting points into credits at the rate of 1,000,000 credits per vote
#USAGE: !VOTEEXCHANGE <Amount>
	if [ "$#" -ne "2" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !VOTEEXCHANGE <Amount>\n'"
	else
		if [ $2 -gt 0 ] 2>/dev/null
		then
			BALANCECREDITS=$(grep CreditsInBank $PLAYERFILE/$1 | cut -d= -f2 | tr -d ' ')
			VOTEBALANCE=$(grep "VotingPoints=" $PLAYERFILE/$1 | cut -d= -f2)
			if [ $VOTEBALANCE -ge $2 ]
			then
				NEWVOTE=$(($VOTEBALANCE - $2))
				NEWCREDITS=$(($BALANCECREDITS + $CREDITSPERVOTE * $2))
				as_user "sed -i 's/CreditsInBank=.*/CreditsInBank=$NEWCREDITS/g' $PLAYERFILE/$1"
				as_user "sed -i 's/VotingPoints=.*/VotingPoints=$NEWVOTE/g' $PLAYERFILE/$1"
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 You traded in $2 voting points for $(($BALANCECREDITS + $CREDITSPERVOTE * $2)) credits. The credits have been sent to your bank account.\n'"
			else
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 You dont have enough voting points to do that! You only have $VOTEBALANCE voting points\n'"
			fi
		else
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid amount entered. Please only use positive whole numbers.\n'"
		fi
	fi
}

#Rank Commands
function COMMAND_RANKME(){
#Tells you what your rank is and what commands are available to you
#USAGE: !RANKME
	if [ "$#" -ne "1" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !RANKME\n'"
	else
			USERRANK=$(sed -n '3p' "$PLAYERFILE/$PLAYERCHATID" | cut -d" " -f2 | cut -d"[" -f2 | cut -d"]" -f1)
			USERCOMMANDS=$(grep $USERRANK $RANKCOMMANDS | cut -d" " -f2-)
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 $1 rank is $USERRANK\n'" 
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Commands available are $USERCOMMANDS\n'" 
	fi
}
function COMMAND_RANKLIST(){
#Lists all the available ranks
#USAGE: !RANKLIST
	if [ "$#" -ne "1" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !RANKLIST\n'"
	else
	    LISTRANKS=( $(cut -d " " -f 1 $RANKCOMMANDS) )
		CHATLIST=${LISTRANKS[@]}	
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 The Ranks are: $CHATLIST \n'"
	fi
}
function COMMAND_RANKSET(){
#Sets the rank of the player
#USAGE: !RANKSET <Player> <Rank>
	if [ "$#" -ne "3" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !RANKSET <Name> <Rank>\n'"
	else
		if ! grep -q $3 $RANKCOMMANDS
		then
			if [ -e $PLAYERFILE/$2 ]
			then
				as_user "sed -i '3s/.*/Rank: \[$3\]/g' $PLAYERFILE/$2"
			else
				MakePlayerFile $2
				as_user "sed -i '3s/.*/Rank: \[$3\]/g' $PLAYERFILE/$2"
			fi
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 $2 is now the rank $3\n'"
		else
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 That rank does not exist\n'"
		fi
	fi
}
function COMMAND_RANKUSER(){
#Finds out the rank of the given player
#USAGE: !RANKUSER <Player>
	if [ "$#" -ne "2" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !RANKUSER <Name>\n'"
	else
		if [ -e $PLAYERFILE/$2 ]
		then
			RANKUSERSTING=$(sed -n '3p' $PLAYERFILE/$2 | cut -d" " -f2)
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 $RANKUSERSTING\n'"
		else
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 $2 has no current Rank or does not exist\n'"
		fi
	fi
}
function COMMAND_RANKCOMMAND(){
#Lists all commands available to you
#USAGE: !RANKCOMMAND
	if [ "$#" -ne "1" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !RANKCOMMAND\n'"
	else		
		RANKUCOMMAND=$(grep $PLAYERRANK $RANKCOMMANDS | cut -d" " -f2-)
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Commands are $RANKUCOMMAND\n'"
	fi
}

#Functional Commands

function COMMAND_VOTEBALANCE(){ 
#Tells you how many voting points you have saved up
#USAGE: !VOTEBALANCE
	as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 You have $(grep "VotingPoints=" $PLAYERFILE/$1 | cut -d= -f2 | tr -d " " ) votes to spend!\n'"
}

#Utility Commands
function COMMAND_HELP(){ 
#Provides help on any and all functions available to the player
#USAGE: !HELP <Command (optional)>
	if [ "$#" -gt "2" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !HELP <Command (Optional)>\n'"
	else		
		PLAYERRANK[$1]=$(grep "Rank=" $PLAYERFILE/$1 | cut -d= -f2)
		ALLOWEDCOMMANDS[$1]=$(grep $PLAYERRANK $RANKCOMMANDS)
		HELPCOMMAND=$(echo $2 | tr [a-z] [A-Z])
		if [ "$#" -eq "1" ]
		then
			if [[ "${ALLOWEDCOMMANDS[$1]}" =~ "-ALL-" ]]
			then
				OLD_IFS=$IFS
				IFS=$'\n'
				for LINE in $(tac $DAEMONPATH)
				do
					if [[ $LINE =~ "function COMMAND_" ]] && [[ ! $LINE =~ "#" ]] && [[ ! $LINE =~ "\$" ]]
					then
						as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 $(echo $LINE | cut -d"_" -f2 | cut -d"(" -f1) \n'"
					fi
				done
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Type !HELP <Command> to get more info about that command!\n'"
				IFS=$OLD_IFS
			else
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 $(echo ${ALLOWEDCOMMANDS[$1]} | cut -d" " -f2-)\n'"
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 All available commands are:\n'"
			fi
		else
			function_exists "COMMAND_$HELPCOMMAND"
			if [[ "$FUNCTIONEXISTS" == "0" ]]
			then
				if [[ "${ALLOWEDCOMMANDS[$1]}" =~ "$HELPCOMMAND" ]] || [[ "${ALLOWEDCOMMANDS[$1]}" =~ "-ALL-" ]]
				then
					OLDIFS=$IFS
					IFS=$'\n'
					HELPTEXT=( $(grep -A3 "function COMMAND_$HELPCOMMAND()" $DAEMONPATH) )
					as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 $(echo ${HELPTEXT[2]} | cut -d\# -f2)\n'"
					as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 $(echo ${HELPTEXT[1]} | cut -d\# -f2)\n'"
					IFS=$OLDIFS
				else
					as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 You dont have permission to use $2\n'"
				fi
			else
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 That command doesnt exist.\n'"
			fi
		fi
	fi
}
function COMMAND_CORE(){
#Provides you with a ship core. Only usable once every 10 minutes
#USAGE: !CORE
	if [ "$#" -ne "1" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !CORE\n'"
	else	
		OLDPLAYERLASTCORE=$(grep PlayerLastCore $PLAYERFILE/$1 | cut -d= -f2- | tr -d ' ')
		CURRENTTIME=$(date +%s)
		ADJUSTEDTIME=$(( $CURRENTTIME - 600 ))
		if [ "$ADJUSTEDTIME" -gt "$OLDPLAYERLASTCORE" ]
		then
			as_user "screen -p 0 -S $SCREENID -X stuff $'/giveid $1 1 1\n'"
			as_user "sed -i 's/PlayerLastCore=$OLDPLAYERLASTCORE/PlayerLastCore=$CURRENTTIME/g' $PLAYERFILE/$1"
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 You have received one core. There is a 10 minute cooldown before you can use it again\n'"
		else
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Please allow Core command to cooldown. $((600-($(date +%s)-$(grep "PlayerLastCore=" $PLAYERFILE/$1 | cut -d= -f2)))) seconds left\n'"
		fi
	fi
}

function COMMAND_PING(){
#With this command, you can check if the server is responsive
#USAGE: !PING
	as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 !PONG\n'"
}

function COMMAND_LOAD(){
#A little info command to see how much of the system ressources are gathered from the starmade server process
#USAGE: !LOAD
	STAR_LOAD_CPU=$(ps aux | grep java | grep StarMade.jar | grep $PORT | grep -v "rlwrap\|sh" | awk '{print $3}')
	STAR_LOAD_MEM=$(ps aux | grep java | grep StarMade.jar | grep $PORT | grep -v "rlwrap\|sh" | awk '{print $4}')
	as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 CPU: $STAR_LOAD_CPU% MEM: $STAR_LOAD_MEM%.\n'"
	as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Server load is currently:\n'"
}

#Vanilla Admin Commands

function COMMAND_LOADSHIP(){
#Spawns in the specified ship from the catalogue to the specified coords
#USAGE: !LOADSHIP <Blueprint Name> <Entity Name> <X> <Y> <Z>
	if [ "$#" -ne "6" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !LOADSHIP <Blueprint Name> <Entity Name> <X> <Y> <Z>\n'"
	else
		as_user "screen -p 0 -S $SCREENID -X stuff $'/spawn_entity $2 $3 $4 $5 $6 0 false\n'"
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 The blueprint $2 has been spawned in sector $4,$5,$6 and is called $3\n'"
	fi
}
function COMMAND_GIVEMETA(){ 
#Gives you, or another player the specified meta item
#USAGE: !GIVEMETA <Player (optional)> <METAUTEN>
	if [ "$#" -ne "2" ] && [ "$#" -ne "3" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !GIVE <Playername (optional)> <Metaitem>\n'"
	else
		if [ "$#" -eq "2" ] 2>/dev/null
		then
			as_user "screen -p 0 -S $SCREENID -X stuff $'/give_metaitem $1 $2\n'"
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 You received $2\n'"
		else
			as_user "screen -p 0 -S $SCREENID -X stuff $'/give_metaitem $2 $3\n'"
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 $2 received $3\n'"
		fi
	fi
}
function COMMAND_CLEAR(){
#Removes all items from your inventory
#USAGE: !CLEAR
	if [ "$#" -ne "1" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !CLEAR\n'"
	else	
		as_user "screen -p 0 -S $SCREENID -X stuff $'/give_all_items $1 -99999\n'"
as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Your inventory has been cleaned\n'"		
	fi
}
function COMMAND_SPAWNSTOP(){
#Prevents enemies from attacking you while insider the specified sector
#USAGE: !SPAWNSTOP <X> <Y> <Z>
	if [ "$#" -ne "4" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !SPAWNSTOP <X> <Y> <Z>\n'"
	else		
		as_user "screen -p 0 -S $SCREENID -X stuff $'/sector_chmod $2 $3 $4 + peace\n'"
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Sector $2,$3,$4 is no longer hostile\n'"
	fi
}
function COMMAND_SPAWNSTART(){
#Allows enemies to start attacking you inside the specified sector
#USAGE: !SPAWNSTART <X> <Y> <Z>
	if [ "$#" -ne "4" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !SPAWNSTART <X> <Y> <Z>\n'"
	else		
		as_user "screen -p 0 -S $SCREENID -X stuff $'/sector_chmod $2 $3 $4 - peace\n'"
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Sector $2,$3,$4 is hostile again\n'"
	fi
}

#Debug Commands
function COMMAND_MYDETAILS(){
#Tells you all details that are saved inside your personal player file
#USAGE: !MYDETAILS
	if [ "$#" -ne "1" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !MYDETAILS\n'"
	else
		for ENTRY in $(tac $PLAYERFILE/$1)
		do
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 $ENTRY\n'"
		done		
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 All details inside your playerfile:\n'"
	fi
}
function COMMAND_THREADDUMP(){
#A debug tool that outputs what the server is doing to a file
#USAGE: !THREADDUMP
	if [ "$#" -ne "2" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !THREADDUMP\n'"
	else
		PID=$(ps aux | grep -v grep | grep $SERVICE | grep -v tee | grep port:$PORT | awk '{print $2}') 
		as_user "jstack $PID >> $STARTERPATH/logs/threaddump$(date +%H%M%S.%N).log"
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 The current java process has been exported to logs/threaddump$(date +%H%M%S.%N).log\n'"
	fi
}

#------------------------------Start of daemon script-----------------------------------------

depcheck
sm_config

# End of regular Functions and the beginning of alias for commands, custom functions, and finally functions that use arguments. 
case "$1" in
start)
	sm_start
	;;
status)
	sm_status
	;;
detect)
	sm_detect
	;;
log)
	sm_log
	;;
screenlog)
	sm_screenlog
	;;
stop)
	sm_stop
	;;
ebrake)
	sm_ebrake
	;;
upgrade)
	sm_upgrade
	;;
cronstop)
	sm_cronstop
	;;
cronrestore)
	sm_cronrestore
	;;
cronbackup)
	sm_cronbackup
	;;
check)
	sm_check
	;;
precheck)
	sm_precheck
	;;
install)
	sm_install
	;;
destroy)
	sm_destroy
	;;
backup)
	sm_backup
	;;
livebackup)
	sm_livebackup
	;;
smsay)
	sm_say $@
	;;
smdo)
	sm_do $@
	;;
setplayermax)
	sm_setplayermax $@
	;;
restore)
	sm_restore $@
	;;
ban)
	sm_ban $@
	;;
dump)
	sm_dump $@
	;;
box)
	sm_box $@
	;;
help)
	sm_help
	;;
reinstall)
	sm_cronstop
	sm_stop
	sm_destroy
	sm_install
	sm_cronrestore
	;;
restart)
	sm_stop
	sm_start
	;;
backupstar)
	sm_cronstop
	sm_stop
	sm_backup
	sm_start
	sm_cronrestore
	;;
upgradestar)
	sm_cronstop
	sm_stop
	sm_upgrade
	sm_start
	sm_cronrestore
	;;
updatefiles)
	update_daemon
	;;
debug) 
	echo ${@:2}
	parselog ${@:2}
	;;
*)
echo "DTSDlite V 0.9.0-alpha"
echo "Usage: starmaded.sh {help|updatefiles|start|stop|ebrake|install|reinstall|restore|status|destroy|restart|upgrade|upgradestar|smdo|smsay|cronstop|cronbackup|cronrestore|backup|livebackup|backupstar|setplayermax|detect|log|screenlog|check|precheck|ban|dump|box}"
#******************************************************************************
exit 1
;;
esac
exit 0
# Notes:  When executing smdo and smsay enclose in "" and escape any special characters
# All chat commands require a ! in front of them and the commands are always in caps

