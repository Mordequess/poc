#! /bin/sh
exit
#############################################################################
# CheckErr.sh written by Michael Cole 2015/05/30 for Logiq3
# ---------------------------------------------------------------------------
# Purpose:
# This script will go through a list of router/router ports (or switch ports)
# it will compare last state (if there is one, if not assume zero) with current
# for specified ports. If there is a change, send an email and record updates.
# ---------------------------------------------------------------------------
# Arguements:
# $0 = This script file name
# $1 = Master Server list (include email alert recipients)
# $2 = SNMP Read community name
# $3 = Router Ports list
# ---------------------------------------------------------------------------

if [ $# != 3 ] ; then
  echo "Usage: $0 <MasterList> <RO Community> <RouterPortsList>"
  exit
fi

ScriptName=`echo $0 | awk -F/ '{print $NF}'`	# Read program name to meaningful variable
MasterList=$1					# Master Server List to meaningful variable
SNMPCommunity=$2				# Read community name to meaningful variable
ErrList=$3					# Read port error list to meaningful variable
SNMPGET=/usr/bin/snmpget			# Prefered SNMPget command
SNMPWALK=/usr/bin/snmpwalk			# Prefered SNMPwalk command
MIBPATH=/usr/share/snmp/mibs			# Path to all SNMP MIBs
SNMPOptions="-v 2c -c"				# Options for SNMPget/walk
VarLoc=4					# Output location from SNMPget of actual value
TmpDir=/tmp					# location of temporary files
WorkDir=/home/scripts/ErrorMonitor		# Working directory
TmpFile=$TmpDir/TMP_$$.txt			# Temporary working file, contains output from GetRouterIfError.sh
TmpFile2=$TmpDir/TMP2_$$.txt			# Temporary working file, contains output from last run of this script
NewFile=$TmpDir/TMP3_$$.txt			# Temporary new ErrList file will replace current
Email=$TmpDir/TMP4_$$.txt			# Body of email message to send

EmailDest=`cat $MasterList | grep ^~~sev | awk -F~ '{print $4}'`
EmailFrom=`cat $MasterList | grep ^~~send | awk -F~ '{print $4}'`
RelayLine=`cat $MasterList | grep -m 1 ^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*.*relay`
RelayServer=`echo $RelayLine | awk -F: '{print $1}'`

if [ ! -e $ErrList ] ; then
  echo "$ErrList does not exist, exiting"
  exit
fi

LineCounter=1
LastLine=`wc -l $ErrList | awk '{print $1}'`
while (( LineCounter <= LastLine ))
do
  line=`head -n $LineCounter $ErrList | tail -n 1`
  ifLine=`echo $line | grep ^interface`
  if [ $? -eq 0 ] ; then
    RouterName=`echo $line | awk -F: '{print $2}'`
    InterfaceName=`echo $line | awk -F: '{print $3}'`
    $WorkDir/GetRouterIfError.sh $RouterName $SNMPCommunity $InterfaceName > $TmpFile
    let NumLeft=$LastLine-$LineCounter
    NextIfLine=`tail -n $NumLeft $ErrList | grep -m 1 -n ^interface | awk -F: '{print $1}'`
    if [ -z "$NextIfLine" ] ; then
      let NextIfLine=$LastLine-$LineCounter+1
    else
      let NextIfLine=$NextIfLine-1
    fi
    tail -n $NumLeft $ErrList | head -n $NextIfLine > $TmpFile2
    diff $TmpFile2 $TmpFile > /dev/null
    DiffResult=$?				# IF DiffResult != 0 then change in error state on InterfaceName
    if [ $DiffResult -ne 0 ] ; then
      echo "On $RouterName Interface: $InterfaceName the error count has changed!" >> $Email
      echo "Old values:" >> $Email
      cat $TmpFile2 >> $Email
      echo "=============================================================" >> $Email
      echo "Current, observed values:" >> $Email
      cat $TmpFile >> $Email
      echo "*************************************************************" >> $Email
    fi
    echo "interface:$RouterName:$InterfaceName" >> $NewFile
    cat $TmpFile >> $NewFile
    rm $TmpFile $TmpFile2
  fi
  (( LineCounter += 1 ))
done

if [ -e $Email ] ; then
		## XXX BUGBUG XXX ##
		## remove the next line
		EmailDest="mcole@theorem.ca"
  /usr/local/bin/sendEmail -f "$EmailFrom" -t "$EmailDest" -u "Interface error count change detected" -s "$RelayServer" -o message-file="$Email" > /dev/null
  rm $Email
fi

rm $ErrList
mv $NewFile $ErrList
