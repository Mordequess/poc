#! /bin/sh
#############################################################################
# AKCPLog.sh written by Michael Cole 2013/12/10 for Logiq3
# ---------------------------------------------------------------------------
# Purpose:
# This script will inspect a specific AKCP by IP and if there is an
# alert, will echo '2,<system name>', warning '1,<system name>', fine
# '0,<system name>'.
# Will update (if needed) the AKCP history for that IP.
# ---------------------------------------------------------------------------
# Arguements:
# $0 = This script file name
# $1 = IP to check on
# ---------------------------------------------------------------------------

if [ $# != 1 ] ; then
  echo "Usage: $0 <IP address>"
  exit
fi

ScriptNameWPath=$0				# Read program name to meaningful variable
System2Check=$1					# Read IP to meaningful name
ScriptsDir=/home/scripts			# location of the scripts directory
AKCPHist=$ScriptsDir/AKCPHistory		# location of all AKCP logs, i.e. state changes
HistFile=$AKCPHist/"$System2Check"_hist.txt	# system history
TmpDir=/tmp					# location of temporary files
SNMPWALK=/usr/bin/snmpwalk			# Prefered SNMPwalk command
SNMPGET=/usr/bin/snmpget			# Prefered SNMPget command
MIBPATH=/usr/share/snmp/mibs			# Path to all SNMP MIBs
SNMPOptions="-m $MIBPATH/AKCP-MIB.txt -v 1 -c"	# Options for SNMPget/walk
SNMPCommunity="logiq3read"			# specify read community
VarLoc=4					# Output location from SNMPget of actual value

SysNm=`$SNMPGET $SNMPOptions $SNMPCommunity $System2Check sysName.0 | awk -F\" '{print $2}' | tr ' ' '_'`
Status=0

NumIf=`$SNMPWALK $SNMPOptions $SNMPCommunity $System2Check sensorProbeTempDegree | wc -l`
index=0
while (( index < NumIf ))
do
  IfOperStat=`$SNMPGET $SNMPOptions $SNMPCommunity $System2Check sensorProbeTempGoOnline.$index | awk '{print $VL}' VL=$VarLoc`
  IsDown=`echo $IfOperStat | grep goOffline`
  if [ -n "$IsDown" ] ; then
    # This Interface is down, lets skip it.
    (( index += 1 ))
    continue
  fi
  TempHiCrit=`$SNMPGET $SNMPOptions $SNMPCommunity $System2Check sensorProbeTempHighCritical.$index | awk '{print $VL}' VL=$VarLoc`
  TempHiWarn=`$SNMPGET $SNMPOptions $SNMPCommunity $System2Check sensorProbeTempHighWarning.$index | awk '{print $VL}' VL=$VarLoc`
  TempLoWarn=`$SNMPGET $SNMPOptions $SNMPCommunity $System2Check sensorProbeTempLowWarning.$index | awk '{print $VL}' VL=$VarLoc`
  TempLoCrit=`$SNMPGET $SNMPOptions $SNMPCommunity $System2Check sensorProbeTempLowCritical.$index | awk '{print $VL}' VL=$VarLoc`
  Temp=`$SNMPGET $SNMPOptions $SNMPCommunity $System2Check sensorProbeTempDegree.$index | awk '{print $VL}' VL=$VarLoc`
  if (( TempHiCrit <= Temp )) || (( TempLoCrit >= Temp )) ; then
	  # Temperature is critical, that means we have a red alarm, so we stop here with a red alert.
	  Status=2
	  index=$NumIf
	  continue
  elif (( TempHiWarn <= Temp )) || (( TempLoWarn >= Temp )) ; then
	  # Temperature is warning, that means we have a yellow alarm, since we have not yet exited we were already
	  # at green or yellow, so we set the alert level to yellow and carry on, in case there's a red somewhere.
	  Status=1
  fi
  # No need to check for green, we know we are between the warning low and high thresholds and the Status was set to 0 at the beginning.
  HumidHiCrit=`$SNMPGET $SNMPOptions $SNMPCommunity $System2Check sensorProbeHumidityHighCritical.$index | awk '{print $VL}' VL=$VarLoc`
  HumidHiWarn=`$SNMPGET $SNMPOptions $SNMPCommunity $System2Check sensorProbeHumidityHighWarning.$index | awk '{print $VL}' VL=$VarLoc`
  HumidLoWarn=`$SNMPGET $SNMPOptions $SNMPCommunity $System2Check sensorProbeHumidityLowWarning.$index | awk '{print $VL}' VL=$VarLoc`
  HumidLoCrit=`$SNMPGET $SNMPOptions $SNMPCommunity $System2Check sensorProbeHumidityLowCritical.$index | awk '{print $VL}' VL=$VarLoc`
  Humid=`$SNMPGET $SNMPOptions $SNMPCommunity $System2Check sensorProbeHumidityPercent.$index | awk '{print $VL}' VL=$VarLoc`
  if (( HumidHiCrit <= Humid )) || (( HumidLoCrit >= Humid )) ; then
	  # Humidity is critical, that means we have a red alarm, so we stop here with a red alert.
	  Status=2
	  index=$NumIf
	  continue
  elif (( HumidHiWarn <= Humid )) || (( HumidLoWarn >= Humid )) ; then
	  # Humidity is warning, that means we have a yellow alarm, since we have not yet exited we were already
	  # at green or yellow, so we set the alert level to yellow and carry on, in case there's a red somewhere.
	  Status=1
  fi
  (( index += 1 ))
done

# We have our alert level, now lets update the log file.
if [ ! -e $HistFile ] ; then
	# Historical File Does not exist, create one
	touch $HistFile
	LastState=EMPTY
else
	LastLine=`tail -n 1 $HistFile`
	LastState=`echo $LastLine | awk -F, '{print $1}'`
fi

DATE=`date`

if (( Status == 2 )) ; then
	# ASSERT: we have a red alarm
	echo "$SysNm,RED"
	if [ $LastState = "GREEN" ] || [ $LastState = "YELLOW" ] || [ $LastState = "EMPTY" ] ; then
		echo "RED,$DATE" >> $HistFile
	fi
elif (( Status == 1 )) ; then
	# ASSERT: we have a yellow warning
	echo "$SysNm,YELLOW"
	if  [ $LastState = "GREEN" ] || [ $LastState = "RED" ] || [ $LastState = "EMPTY" ] ; then
		echo "YELLOW,$DATE" >> $HistFile
	fi
else
	# ASSERT: Status == 0, we have a green, all environmental OKAY
	echo "$SysNm,GREEN"
	if  [ $LastState = "YELLOW" ] || [ $LastState = "RED" ] || [ $LastState = "EMPTY" ] ; then
		echo "GREEN,$DATE" >> $HistFile
	fi
fi
