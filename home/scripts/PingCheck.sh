#! /bin/sh
#############################################################################
# PingCheck.sh written by Michael Cole 2013/08/28 for Logiq3
# ---------------------------------------------------------------------------
# Purpose:
# This script will ping all systems tagged in the master configuration file.
# This script will email on any system that does not respond to three pings.
# ---------------------------------------------------------------------------
# Arguements:
# $0 = This script file name
# $1 = The master configuration file.
#############################################################################

TMPDIR=/tmp				# location of the temporary directory
DelayInSec=3600				# Time in seconds between emails of alerts
ScriptsHome=/home/scripts		# Location of non-mrtg scripts
WorkDIR=$ScriptsHome/PingData		# location of previous output runs
SNMPCommunity="logiq3read"		# specify read community
SNMPGET=/usr/bin/snmpget		# Prefered SNMPget command
SNMPWALK=/usr/bin/snmpwalk		# Prefered SNMPwalk command
SNMPOptions="-m all -v 2c -c"		# Options for SNMPget/walk
VarLoc=4				# Output location from SNMPget of actual value
HTTPErrReport=$TMPDIR/HTTP_ERR_RPT	# HTTP Error log, to be included in email alerts for debugging


if [ $# != 1 ] ; then
  echo "Usage: $0 <Master Configuration file name and path>"
  exit
fi

ScriptName=`echo $0 | awk -F/ '{print $NF}'`	# Read program name to meaningful variable
						# What if program is called with absoulte file location?
CfgFile=$1					# Read the config file name and path into meaningful variable

function PurgeStalelogs {
  #######################################################################
  # Purpose: Delete old EmailedAlerts files, if there are any.
  # ---------------------------------------------------------------------
  # Arguements:
  # $1 - Time in seconds since 1970-01-01 00:00:00 UTC
  ####################################################################### 
  PurgeLS=$TMPDIR/purgels.$$		# Temporary list of all files in in WorkDIR

  let TooOld=$1-$DelayInSec
  ls -l $WorkDIR | awk '{print $9}' > $PurgeLS
					# Really only care about file name but want one file per line
  LineCount=`wc -l $PurgeLS | awk '{print $1}'`
  index=1
  while (( index <= LineCount ))
  do
    line=`head -n $index $PurgeLS | tail -n 1`
    if [ -z "$line" ] ; then
      # ls returns empty lines, so we skip those
      (( index += 1 ))
      continue
    fi
    FileDate=`echo $line | awk -F. '{print $2}'`
    if (( FileDate <= TooOld )) ; then
      # File: $line is too old and should be deleted
      rm $WorkDIR/$line
    fi
    (( index += 1 ))
  done

  rm $PurgeLS
} ##################### END PurgeStalelogs

function GenAlertsFile {
  #######################################################################
  # Purpose: Process the latest log of down systems and see which ones
  #          have not already alerts in the last hour
  # ---------------------------------------------------------------------
  # Arguements:
  # $1 - input, list of all down systems
  #      Each line will take the form: IPaddr~Date~ is not pingable
  # $2 - output list of down systems to alert on.
  # $3 - input, class of outage, i.e. Ping, HTTP, etc.
  #######################################################################

  FileLen=`wc -l $1 | awk '{print $1}'`
  index=1
  while (( index <= FileLen ))
  do
    line=`head -n $index $1 | tail -n 1`
    DownSystem=`echo $line | awk -F~ '{print $1}'`
    Time=`echo $line | awk -F~ '{print $2}'`
    IsAlreadyDown=`cat $WorkDIR/Ping.* 2> /dev/null | grep $DownSystem,.*$3`
    if [ -z "$IsAlreadyDown" ] ; then
      # Assert: If we are at this point we need to alert that DownSystem is down.
      echo "$DownSystem, $Time, $3" >> $2
    fi
    (( index += 1 ))
  done
} ##################### END GenAlertsFile

function BuildMessage {
  #######################################################################
  # Purpose: Take in list of down systems and make human readable
  # ---------------------------------------------------------------------
  # Arguements:
  # $1 - input list of down systems to alert on.
  # $2 - Master configuration file, where system descriptions will be founds
  # $3 - Output file in human readable format
  #######################################################################

  FileLen=`wc -l $1 | awk '{print $1}'`
  index=1
  while (( index <= FileLen ))
  do
    line=`head -n $index $1 | tail -n 1`
    DownSystem=`echo $line | awk -F, '{print $1}'`
    Time=`echo $line | awk -F, '{print $2}'`
    ClassOfOutage=`echo $line | awk -F, '{print $3}' | awk '{print $1}'`
    Description=`cat $2 | grep "$DownSystem:" | awk -F# '{print $2}'`
    echo "The system check that began at $Time detected that $Description" >> $3
    if [ "$ClassOfOutage" = "Ping" ] ; then 
      echo "(IP: $DownSystem) was unpingable." >> $3
    elif [ "$ClassOfOutage" = "HTTP" ] ; then
      echo "(IP: $DownSystem) did not respond to HTTP requests." >> $3
    elif [ "$ClassOfOutage" = "HTTPS" ] ; then
      echo "(IP: $DownSystem) did not respond to HTTPS requests." >> $3
    elif [ "$ClassOfOutage" = "SMTP" ] ; then
      echo "(IP: $DownSystem) did not respond to SMTP requests." >> $3
    elif [ "$ClassOfOutage" = "PoE" ] ; then
      echo "(IP: $DownSystem) had a total power draw from PoE devices that exceeded 80% of available power." >> $3
    fi
    echo "Another check, of all other systems will take place every five minutes." >> $3
    echo "If the system is down in one hour another email notification will be sent." >> $3
    echo "==========================================================================" >> $3
    (( index += 1 ))
  done
  if [ -e $HTTPErrReport ] ; then
    echo "The full HTTP telnet transaction report(s) is/are as follows:" >> $3
    cat $HTTPErrReport >> $3
  fi

} ##################### END BuildMessage

function SMTPTest {
  #######################################################################
  # Purpose: Execute test of SMTP availability on specified host
  # ---------------------------------------------------------------------
  # Arguements:
  # $1 - Input remote host to test SMTP on.
  #######################################################################
  SMTPTestOut=$TMPDIR/SMTPTest.$$
  $ScriptsHome/SMTPtest.sh $1 | telnet > $SMTPTestOut 2> /dev/null
  # If the connection works properly the 'Connection closed by foreign host'
  # gets sent to Errout, hence the redirect 2 to /dev/null. Since this function
  # fails if it does not get very specific strings, we will tolerate the loss
  # of err data.

  Status=`cat $SMTPTestOut | grep -n '^220 SMTP'`
  if [ -z "$Status" ] ; then
  # If status is empty there was no line that begins with 220 SMTP, there must be a problem
    RetVal=1
  else
    LineNumber=`echo $Status | awk -F: '{print $1}'`
    # Now we check the very next line to ensure that it starts with 250 then there is a Hello somewhere
    # further down that line.
    let NextLine=LineNumber+1
    NewLine=`head -n $NextLine $SMTPTestOut | tail -n 1`
    dummy=`echo $NewLine | grep '^250.*Hello'`
    if [ -z "$dummy" ] ; then
      # If dummy is empty then our next line does not match, so we have failed.
      RetVal=1
    else
      RetVal=0
    fi
  fi
  rm $SMTPTestOut
  return $RetVal

} ##################### END SMTPTest

function HTTPTest {
  #######################################################################
  # Purpose: Execute test of HTTP availability on specified host
  # ---------------------------------------------------------------------
  # Arguements:
  # $1 - Input remote host to test HTTP on.
  #######################################################################
  HTTPTestOut=$TMPDIR/HTTPTest.$$
  HTTPErrOut=$TMPDIR/HTTPTest.err.$$
  $ScriptsHome/HTTPTest.sh $1 $CfgFile | telnet > $HTTPTestOut 2> $HTTPErrOut
  # If the connection works properly the 'Connection closed by foreign host'
  # gets sent to Errout, hence the redirect 2 to /dev/null. Since this function
  # fails if it does not get very specific strings, we will tolerate the loss
  # of err data.
  # Note: due to issues with some servers, we are going to capture everything,
  # lets see if there's something in the error string.

  # We will permit:
  # * 2xx - everything is fine.
  # * 3xx - content moved but server is okay
  # * 400 - server didn't understand request, basically my code doesn't
  #         play nice, but the server is fine which is what we actually care about.

  StatusCode=`grep -m 1 HTTP $HTTPTestOut | awk '{print $2}'`
  if [ "$StatusCode" -lt 401 ] && [ "$StatusCode" -gt 199 ] ; then
    RetVal=0
  else
    cat $HTTPTestOut $HTTPErrOut >> $HTTPErrReport
    echo "Hostname: _$1_" >> $HTTPErrReport 
    RetVal=1
  fi
  rm $HTTPTestOut $HTTPErrOut
  return $RetVal

} ##################### END HTTPTest

function HTTPSTest {
  #######################################################################
  # Purpose: Execute test of HTTPS (SSL) availability on specified host
  # ---------------------------------------------------------------------
  # Arguements:
  # $1 - Input remote host to test HTTPS on.
  #######################################################################
  HTTPSTestOut=$TMPDIR/HTTPSTest.$$
  $ScriptsHome/HTTPSTest.sh $1 $CfgFile | openssl > $HTTPSTestOut 2> /dev/null
  # If the connection works properly the 'Connection closed by foreign host'
  # gets sent to Errout, hence the redirect 2 to /dev/null. Since this function
  # fails if it does not get very specific strings, we will tolerate the loss
  # of err data.

  # We will permit:
  # * 2xx - everything is fine.
  # * 3xx - content moved but server is okay
  # * 400 - server didn't understand request, basically my code doesn't
  #         play nice, but the server is fine which is what we actually care about.

  StatusCode=`grep -m 1 HTTP $HTTPSTestOut | awk '{print $2}'`
  if [ "$StatusCode" -lt 401 ] && [ "$StatusCode" -gt 199 ] ; then
    RetVal=0
  else
    RetVal=1
  fi
  rm $HTTPSTestOut
  return $RetVal

} ##################### END HTTPSTest

function PoETest {
  #######################################################################
  # Purpose: Inspect PoE usage, ensure it does not exceed 80% of the max
  #          available
  # ---------------------------------------------------------------------
  # Arguements:
  # $1 - Input remote host to test PoE usage on.
  #######################################################################

  PoETestOut=$TMPDIR/PoETest.$$
  MIB=cpeExtPsePortPwrAvailable

  $SNMPWALK $SNMPOptions $SNMPCommunity $1 $MIB |  awk -F: '{print $VL}' VL=$VarLoc | awk '{print $1}' > $PoETestOut
  TotalPower=0
  for Port in `cat $PoETestOut`
  do
    TotalPower=`expr $TotalPower + $Port`
  done
  rm $PoETestOut

  ## N.B. TotalPower is in milliwatts, the only place I could find max power
  ## was a different MIB that uses watts, and we can only do integer division.
  ## So what we do is, take (total power used in milliwatts) / (max available power in watts)
  ## if the result is more than 800 we know we are in a bad place, i.e. over 80% load.

  MaxPower=`$SNMPWALK $SNMPOptions $SNMPCommunity $1 pethMainPsePower | awk -F: '{print $VL}' VL=$VarLoc | awk '{print $1}' | paste -sd+ | bc`

  let load="TotalPower / MaxPower"
  if [ "$load" -gt 800 ] ; then
    RetVal=1
  else
    RetVal=0
  fi
  return $RetVal

} ##################### END PoETest

##################### BEGIN MAIN #####################

DateInSec=`date +%s`				# Time in seconds since 1970-01-01 00:00:00 UTC
DateReadable=`date`				# Date in readable form, i.e. Mon Sep  9 13:47:54 EDT 2013
EmailedAlerts=$WorkDIR/Ping.$DateInSec		# List of systems emailed
PING=/bin/ping					# Ping command to use
PINGARGS="-c 3"					# Arguments for the ping command
ErrFile=$TMPDIR/$ScriptName.$$			# Ping Error file
HTTPErrFile=$WorkDIR/HTTP.$DateInSec		# HTTP Error file
HTTPSErrFile=$WorkDIR/HTTPS.$DateInSec		# HTTPS Error file
PoEErrFile=$WorkDIR/PoE.$DateInSec		# PoE Error file
SMTPErrFile=$WorkDIR/SMTP.$DateInSec		# SMTP error file (cannot email this one!)
TmpPingErr=$TMPDIR/TPE.$$			# If a system was unpingable and is now pingable use this as a temporary
						# file to record the change of state

PurgeStalelogs $DateInSec &
if [ -e $HTTPErrReport ] ; then
  rm $HTTPErrReport
fi

CfgFileLen=`wc -l $CfgFile | awk '{print $1}'`
index=1
while (( index <= CfgFileLen ))
do
  line=`head -n $index $CfgFile | tail -n 1`
  # We need to ensure the line leads with an IP, otherwise skip.
  dummy=`echo $line | grep  '^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}'`
  if [ -z "$dummy" ] ; then
    # string does not lead with IP so we need to skip
    (( index += 1 ))
    continue
  fi
  # ASSERT: the line starts with an IP address
  # is there a ping statement in the line, we count colon delmited fields
  NumFields=`echo $line | awk -F: '{print NF}'`
  if (( NumFields == 1)) ; then
    # ASSERT: there is no colon on this line thus no tags to this IP
    (( index += 1 ))
    continue
  fi
  # ASSERT: there is at least one colon on this line after an IP address
  # Lets get the IP and go through each tag
  IPaddr=`echo $line | awk -F: '{print $1}'`
  SubIndex=2
  while (( SubIndex <= NumFields ))
  do
    # Many lines have comments after the tag, we need to ensure that we only capture
    # colon and space delimited data, then lower case it so we are case insensitve
    tag=`echo $line | awk -F: '{print $SI}' SI=$SubIndex | awk '{print $1}' | awk '{print tolower($0)}'`
    if [ "$tag" = "ping" ] ; then
      $PING $PINGARGS $IPaddr > /dev/null
      RetVal=$?
      if (( RetVal != 0 )) ; then
        # Some error occured when pinging
        echo "$IPaddr~$DateReadable~ is not pingable" >> $ErrFile
      else
	# System is pingable, need to check if it wasn't last run
	if [ "$(ls -A $WorkDIR/)" ] ; then
	  DownFile=`grep -H $IPaddr, $WorkDIR/*`
	  IsDown=$?
	else
	  IsDown=1
        fi
	if (( IsDown == 0 )) ; then
	  ## System is up now, but was recorded as down last run.
	  DownFileName=`echo $DownFile | awk -F: '{print $1}'`
	  grep -v "$IPaddr.*Ping" $DownFileName > $TmpPingErr
	  rm $DownFileName
	  mv $TmpPingErr $DownFileName
        fi
      fi
    elif [ "$tag" = "relay" ] ; then
      RelayServer=$IPaddr
    elif [ "$tag" = "smtp" ] ; then
      SMTPTest $IPaddr
      RETVAL=$?
      if (( RETVAL == 1 )) ; then
        echo "$IPaddr~$DateReadable~ SMTP service has a problem!!" >> $SMTPErrFile
      fi
    elif [ "$tag" = "poe" ] ; then
      PoETest $IPaddr
      RETVAL=$?
      if (( RETVAL == 1 )) ; then
	echo "$IPaddr~$DateReadable~ PoE device power load exceeds 80% on this switch" >> $PoEErrFile
      fi
    elif [ "$tag" = "http" ] ; then
      HTTPTest $IPaddr
      RETVAL=$?
      if (( RETVAL == 1 )) ; then
	# Need to repeat the test a couple times to be sure it really is down,
	# a lot of sites seem to need multiple tests.
	sleep 2
	HTTPTest $IPaddr
	RETVAL=$?
	if (( RETVAL == 1 )) ; then
	  sleep 2
	  HTTPTest $IPaddr
	  RETVAL=$?
	  if (( RETVAL == 1 )) ; then
	    echo "$IPaddr~$DateReadable~ HTTP service is not working" >> $HTTPErrFile
	  fi
	fi
      fi
    elif [ "$tag" = "https" ] ; then
      HTTPSTest $IPaddr
      RETVAL=$?
      if (( RETVAL == 1 )) ; then
	# Need to repeat the test a couple times to be sure it really is down,
	# a lot of sites seem to need multiple tests.
	sleep 2
	HTTPSTest $IPaddr
	RETVAL=$?
	if (( RETVAL == 1 )) ; then
	  sleep 2
	  HTTPSTest $IPaddr
	  RETVAL=$?
	  if (( RETVAL == 1 )) ; then
     	    echo "$IPaddr~$DateReadable~ HTTPS service is not working" >> $HTTPSErrFile
	  fi
	fi
      else
	# HTTPS is working, likely this system is not ping'd so need to check if it wasn't last run
	if [ "$(ls -A $WorkDIR/)" ] ; then
	  DownFile=`grep -H $IPaddr, $WorkDIR/*`
	  IsDown=$?
	else
	  IsDown=1
        fi
	if (( IsDown == 0 )) ; then
	  ## System is up now, but was recorded as down last run.
	  DownFileName=`echo $DownFile | awk -F: '{print $1}'`
	  grep -v $IPaddr $DownFileName > $TmpPingErr
	  rm $DownFileName
	  mv $TmpPingErr $DownFileName
        fi
      fi
    fi
    (( SubIndex += 1 ))
  done
  (( index += 1 ))
done

if [ -f $ErrFile ] ; then
  GenAlertsFile $ErrFile $EmailedAlerts Ping
  rm $ErrFile
fi

if [ -f $PoEErrFile ] ; then
  GenAlertsFile $PoEErrFile $EmailedAlerts PoE
  rm $PoEErrFile
fi

if [ -f $HTTPErrFile ] ; then
  GenAlertsFile $HTTPErrFile $EmailedAlerts HTTP
  rm $HTTPErrFile
fi

if [ -f $HTTPSErrFile ] ; then
  GenAlertsFile $HTTPSErrFile $EmailedAlerts HTTPS
  rm $HTTPSErrFile
fi

if [ -f $SMTPErrFile ] ; then
  GenAlertsFile $SMTPErrFile $EmailedAlerts SMTP
  rm $SMTPErrFile
fi

if [ -z "$RelayServer" ] ; then
  echo "Big problem!! No SMTP Relay server is setup"
  exit 1
fi

if [ -e $EmailedAlerts ] ; then
  BuildMessage $EmailedAlerts $CfgFile $ErrFile
  # We need to send EmailedAlerts out, if it doesn't exist, there's nothing to alert we are done.
  SENDER=`cat $CfgFile | grep "^~~send" | awk -F~ '{print $4}'`
  RECIP=`cat $CfgFile | grep "^~~sev" | awk -F~ '{print $4}'`
  /usr/local/bin/sendEmail -f "$SENDER" -t "$RECIP" -u "System Down Alert" -s "$RelayServer" -o message-file="$ErrFile" > /dev/null
  rm $ErrFile
fi
