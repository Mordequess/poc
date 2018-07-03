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
TmpDir=/tmp					# location of temporary files

# Need to ensure user specifed port exists, and there is only one port that matches
RetCount=`snmpwalk -v 2c -c logiq3read 172.20.0.1 ifDescr | grep -i $Ifname\$ | wc -l`
if [ $RetCount != 1 ] ; then
  echo "Specified switch port not found, available ports are:"
  $SNMPWALK $SNMPOptions $SNMPCommunity $SwitchIP ifDescr
  exit
fi

IfIndex=`$SNMPWALK $SNMPOptions $SNMPCommunity $SwitchIP ifDescr | grep -i $Ifname\$`
IfIndex=`echo $IfIndex | awk -F. '{print $2}' | awk '{print $1}'`

InDiscards=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP ifInDiscards.$IfIndex | awk -F: '{print $vl}' vl=$VarLoc | awk '{print $1}'`
InErrors=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP ifInErrors.$IfIndex | awk -F: '{print $vl}' vl=$VarLoc | awk '{print $1}'`
InUnknown=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP ifInUnknownProtos.$IfIndex | awk -F: '{print $vl}' vl=$VarLoc | awk '{print $1}'`
OutDiscard=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP ifOutDiscards.$IfIndex | awk -F: '{print $vl}' vl=$VarLoc | awk '{print $1}'`
OutErrors=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP ifOutErrors.$IfIndex | awk -F: '{print $vl}' vl=$VarLoc | awk '{print $1}'`

echo "ifInDiscards:$InDiscards"
echo "ifInErrors:$InErrors"
echo "ifInUnknownProtos:$InUnknown"
echo "ifOutDiscards:$OutDiscard"
echo "ifOutErrors:$OutErrors"
