#! /bin/sh
#############################################################################
# GetRouterIfError.sh written by Michael Cole 2015/05/29 for Logiq3
# ---------------------------------------------------------------------------
# Purpose:
# This script will inspect the specified router port and return all the
# error stats to stdout in the following format:
# <error_description>:<count><NL>
# ---------------------------------------------------------------------------
# Arguements:
# $0 = This script file name
# $1 = IP address or DNS resolvable name of device to query
# $2 = SNMP Read community name
# $3 = Interface to inspect
# ---------------------------------------------------------------------------

if [ $# != 3 ] ; then
  echo "Usage: $0 <RouterIP> <RO Community> <Interface name>"
  exit
fi

ScriptName=`echo $0 | awk -F/ '{print $NF}'`	# Read program name to meaningful variable
SwitchIP=$1					# Read Switch IP to meaningful variable
SNMPCommunity=$2				# Read community name to meaningful variable
Ifname=$3					# Read interface name to meaningful variable
SNMPGET=/usr/bin/snmpget			# Prefered SNMPget command
SNMPWALK=/usr/bin/snmpwalk			# Prefered SNMPwalk command
MIBPATH=/usr/share/snmp/mibs			# Path to all SNMP MIBs
SNMPOptions="-v 2c -c"				# Options for SNMPget/walk
VarLoc=4					# Output location from SNMPget of actual value
EXPECTPATH=/usr/bin/expect			# location of Expect
TmpDir=/tmp					# location of temporary files
TmpScript=$TmpDir/expect_$$.sh			# Temporary expect script to poll values from router
TmpOutput=$TmpDir/output.txt			# Output from expect script

# Need to ensure user specifed port exists, and there is only one port that matches
RetCount=`$SNMPWALK $SNMPOptions $SNMPCommunity $SwitchIP ifDescr | grep -i $Ifname\$ | wc -l`
if [ $RetCount != 1 ] ; then
  echo "Specified switch port not found, available ports are:"
  $SNMPWALK $SNMPOptions $SNMPCommunity $SwitchIP ifDescr
  exit
fi

IFname=`$SNMPWALK $SNMPOptions $SNMPCommunity $SwitchIP ifDescr | grep -i $Ifname\$ | awk '{print $vl}' vl=$VarLoc`

echo "#! $EXPECTPATH -f" > $TmpScript
echo "spawn ssh $SwitchIP" >> $TmpScript
echo "expect \"Password:\"" >> $TmpScript
echo "send \"\\\$2Y2m5h\\\$\\r\"" >> $TmpScript
echo "expect \"#\"" >> $TmpScript
echo "send \"show interface $IFname\r\"" >> $TmpScript
echo "expect \"#\"" >> $TmpScript
echo "send \"exit\r\"" >> $TmpScript

chmod 755 $TmpScript
$TmpScript > $TmpOutput
## XXX BUGBUG XXX
## Done to here need to parse $TmpOutput
## Things to watch for:
## Last clearing of "show interface" counters 8w1d ... not sure how to process that so that it doesn't alert
## Will have to modify the other script - could put this value in beside the interface name.
## XXX BUGBUG XXX

LastClear=`cat $TmpOutput | grep 'Last clearing of'`
cat $TmpOutput | grep 'runts'
cat $TmpOutput | grep 'CRC'
cat $TmpOutput | grep 'dribble'
cat $TmpOutput | grep 'collisions' | tr 'interface' 'Interface'
cat $TmpOutput | grep 'unknown'
cat $TmpOutput | grep 'babbles'
cat $TmpOutput | grep 'carrier'
cat $TmpOutput | grep 'failures'

rm $TmpScript $TmpOutput
