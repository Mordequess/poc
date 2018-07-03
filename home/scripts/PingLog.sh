#! /bin/sh
#############################################################################
# PingLog.sh written by Michael Cole 2013/10/27 for Logiq3
# ---------------------------------------------------------------------------
# Purpose:
# This script will look for a specific IP in the ping logs and if that IP
# is down it will echo "1", else it will echo "0" if up for at least 24 hours,
# if up for less than 24 hours will echo 2. Will return same value.
# Will update (if needed) the ping history for that IP.
# ---------------------------------------------------------------------------
# Arguements:
# $0 = This script file name
# $1 = IP to check on
# ---------------------------------------------------------------------------

if [ $# != 1 ] ; then
  echo "Usage: $0 <IP address>"
  exit
fi

ScriptNameWPath=$0			# Read program name to meaningful variable
System2Check=$1				# Read IP to meaningful name
ScriptsDir=/home/scripts		# location of the scripts directory
PingLog=$ScriptsDir/PingData		# location of all ping events that have happened in the last hour
PingHist=$ScriptsDir/PingHistory	# location of all ping logs, i.e. state changes
TmpDir=/tmp				# location of temporary files

NumDirs=`echo $ScriptNameWPath | awk -F/ '{print NF}'`
ScriptName=`echo $ScriptNameWPath | awk -F/ '{print $nf}' nf=$NumDirs`
TmpFile=$TmpDir/$ScriptName.$$		# Store temporary data here
HistFile=$PingHist/"$System2Check"_hist.txt	# system history
MINDOWNTIME=3590			# Min downtime to ignore alerts on (1 hour less ten seconds)
MAXDOWNTIME=3900			# Max downtime to ignore alerts on (1 hour plus 5 minutes)
ONEDAY=86400				# Number of seconds in 24 hours.
SEC_DATE=`date +%s`			# time in seconds since the EPOCH (Jan 1, 1970)

cat $PingLog/Ping.* 2> /dev/null | grep $System2Check,.*Ping > $TmpFile
if [ ! -e $HistFile ] ; then
	# Historical File Does not exist, create one
	touch $HistFile
	LastState=EMPTY
else
	LastLine=`tail -n 1 $HistFile`
	LastState=`echo $LastLine | awk -F, '{print $1}'`
	# Need to loop through the history file and see if there has been a state change in the last day
	index=1
	LineCount=`wc -l $HistFile | awk '{print $1}'`
	let OneDayAgo=$SEC_DATE-$ONEDAY
	ChangeInLastDay=NO
	while (( index <= LineCount ))
	do
		line=`head -n $index $HistFile | tail -n 1`
		EventDate=`echo $line | awk -F, '{print $2}'`
		EventDateSec=`date +%s -d "$EventDate"`
		if (( EventDateSec >= OneDayAgo )) ; then
			# There has been a state change in the last 24 hours, no need to continue this loop
			ChangeInLastDay=YES
			index=$LineCount
		fi
		(( index += 1 ))
	done
fi

if [ -s $TmpFile ] ; then
	# ASSERT: the system is down
	DATE=`tail -n 1 $TmpFile | awk -F, '{print $2}'`
	RetVal=1
	if [ $LastState = "UP" ] || [ $LastState = "EMPTY" ] ; then
		echo "DOWN,$DATE" >> $HistFile
	fi
else
	# What if 1 hour has passed and the system is still down? Then there won't be a TmpFile
	# but the system is still down. So what we need to do is compare, is last state down and is the time
	# between MIN/MAX DOWNTIME? If so, assume we are still down and don't change state.
	if [ $LastState = "DOWN" ] ; then
		LogDate=`echo $LastLine | awk -F, '{print $2}'`
		LogDateSec=`date +%s -d "$LogDate"`
		let StartWindow=$LogDateSec+$MINDOWNTIME
		let EndWindow=$LogDateSec+$MAXDOWNTIME
		if [ $SEC_DATE -gt $StartWindow ] && [ $SEC_DATE -lt $EndWindow ] ; then
			# ASSERT: the system has been down for about an hour and is probably still down
			RetVal=1
		else
			# ASSERT: the system is up
			if [ "$ChangeInLastDay" == "NO" ] ; then
				RetVal=0
			else
				RetVal=2
			fi
			DATE=`date`
			echo "UP,$DATE" >> $HistFile
		fi
	else
		# ASSERT: LastState = { UP | EMPTY }
		# We will assume the system is up initially
		if [ "$ChangeInLastDay" == "NO" ] ; then
			RetVal=0
		else
			RetVal=2
		fi
		DATE=`date`
		if [ $LastState = "EMPTY" ] ; then
			# If this is a first run, then we start with a 2 for 24 hours.
			echo "UP,$DATE" >> $HistFile
			RetVal=2
		fi
	fi
fi

$ScriptsDir/GenUpTimeHTML.sh $HistFile PING
rm $TmpFile
echo $RetVal
exit $RetVal
