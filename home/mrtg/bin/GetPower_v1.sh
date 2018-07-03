#! /bin/sh
#############################################################################
# GetPower.sh written by Michael Cole 2014/04/14 for Logiq3
# ---------------------------------------------------------------------------
# Purpose:
# This script will return the sum of all values returned by an SNMP walk of:
# cewEntEnergyUsage
# In an MRTG friendly format (MRTG requires two integers (in/out bytes),
# uptime and system name, all four of the above in new line delmited format.)
# ---------------------------------------------------------------------------
# Arguements:
# $0 = This script file name
# $1 = IP address or DNS resolvable name of device to query
# $2 = SNMP Read community name
# ---------------------------------------------------------------------------

if [ $# != 2 ] ; then
  echo "Usage: $0 <SwitchIP> <RO Community>"
  exit
fi

ScriptName=`echo $0 | awk -F/ '{print $NF}'`	# Read program name to meaningful variable
SwitchIP=$1					# Read Switch IP to meaningful variable
SNMPCommunity=$2				# Read community name to meaningful variable
SNMPGET=/usr/bin/snmpget			# Prefered SNMPget command
SNMPWALK=/usr/bin/snmpwalk			# Prefered SNMPwalk command
MIBPATH=/usr/share/snmp/mibs			# Path to all SNMP MIBs
SNMPOptions="-m all -v 2c -c"			# Options for SNMPget/walk
VarLoc=4					# Output location from SNMPget of actual value
TmpDir=/tmp					# location of temporary files
PowerPerPort=$TmpDir/GetPower.$$		# New line delimited power per port on switch

$SNMPWALK $SNMPOptions $SNMPCommunity $SwitchIP cewEntEnergyUsage |  awk -F: '{print $VL}' VL=$VarLoc | awk '{print $1}' > $PowerPerPort

TotalPower=0

for Port in `cat $PowerPerPort`
do
	TotalPower=`expr $TotalPower + $Port`
done

rm $PowerPerPort

## Total power is in milliwatts, but cannot simply divide by 1000 as Bash always rounds down (truncates).
## What to do, is first add 500, then divide by 1000, if value in milliwatts was xyz499, then add 500 and
## divide by 1000 gives, xyz999/1000 = xyz. If value was xyz500 then add 500 and divide gives xy(z+1)000/1000.
## So with the exception that 500 milliwatts always rounds up, (it should round up only sometimes) this algorithm works

TotalPower500=`echo $((TotalPower + 500))`
TotalPower=`echo $((TotalPower500 / 1000))`

echo $TotalPower
echo $TotalPower
$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP sysUpTimeInstance | awk -F\) '{print $2}'
$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP sysName.0 | awk '{print $VL}' VL=$VarLoc
