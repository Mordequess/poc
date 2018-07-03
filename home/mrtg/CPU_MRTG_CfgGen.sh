#! /bin/sh
#############################################################################
# CPU_MRTG_CfgGen.sh written by Michael Cole 2014/06/25 Logiq3
# ---------------------------------------------------------------------------
# Purpose:
# This script will generate a configuration file for use by MRTG for
# monitoring, CPU use. A CSV of image location of daily graph and URL
# to full MRTG page will also be generated.
# ---------------------------------------------------------------------------
# Arguements:
# $0 = This script file name
# $1 = IP address or DNS resolvable name of device to build config against
# $2 = Output MRTG configuration file.
# ---------------------------------------------------------------------------

if [ $# != 2 ] ; then
  echo "Usage: $0 <SwitchIP> <Output MRTG Cfg file>"
  exit
fi

ScriptName=`echo $0 | awk -F/ '{print $NF}'`	# Read program name to meaningful variable
SwitchIP=$1					# Read Switch IP to meaningful variable
MRTGOutfile=$2					# Read output file name to meaningful variable
SNMPGET=/usr/bin/snmpget			# Prefered SNMPget command
SNMPWALK=/usr/bin/snmpwalk			# Prefered SNMPwalk command
MIBPATH=/usr/share/snmp/mibs			# Path to all SNMP MIBs
SNMPOptions="-m all -v 2c -c"			# Options for SNMPget/walk
SNMPCommunity="logiq3read"			# specify read community
VarLoc=4					# Output location from SNMPget of actual value
TmpDir=/tmp					# location of temporary files
MRTGHome=/home/mrtg				# Home directory of MRTG
quote=$'\042'					# This way can embed quotes in an echo, i.e. echo $quote abc $quote, returns " abc "
bang=$'\041'					# As with quotes above, enables us to embed an exclamation, !

# Next line will get the Switch name
SysNm=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP sysName.0 | awk '{print $vl}' vl=$VarLoc`

ToDay=`date +%F`
CSVFile=$TmpDir/$SwitchIP.$ToDay

if [ ! -d /home/mrtg/mrtg/$SysNm ] ; then
  echo "The directory /home/mrtg/mrtg/$SysNm does not exist, I will now create it; however," 1>&2
  echo "if this device was already being monitored all logs need to be moved to this location" 1>&2
  mkdir /home/mrtg/mrtg/$SysNm
fi

echo "# Created by $ScriptName using: $*" > $MRTGOutfile
echo >> $MRTGOutfile
echo "EnableIPv6: no" >> $MRTGOutfile
echo "WorkDir: $MRTGHome/mrtg/$SysNm" >> $MRTGOutfile
echo "RunAsDaemon: Yes" >> $MRTGOutfile
echo "Interval: 5" >> $MRTGOutfile
echo "Options[_]: gauge, nopercent" >> $MRTGOutfile
echo >> $MRTGOutfile
echo >> $MRTGOutfile
echo >> $MRTGOutfile

TargVal="$SwitchIP"_CPU
echo "Target[$TargVal]: 1.3.6.1.4.1.9.9.109.1.1.1.1.8.1&1.3.6.1.4.1.9.9.109.1.1.1.1.8.1:$SNMPCommunity@$SwitchIP" >> $MRTGOutfile
echo "Unscaled[$TargVal]: ymwd" >> $MRTGOutfile
echo "SetEnv[$TargVal]: MRTG_INT_IP=\"\" MRTG_INT_DESCR=\"Percent CPU load\"" >> $MRTGOutfile
echo "MaxBytes[$TargVal]: 100" >> $MRTGOutfile
echo "Title[$TargVal]: %CPU load" >> $MRTGOutfile
echo "PageTop[$TargVal]: <h1>Percent CPU used</h1>" >> $MRTGOutfile
echo -e "\t<div id=\"sysdetails\">" >> $MRTGOutfile
echo -e "\t\t<table>" >> $MRTGOutfile
echo -e "\t\t\t<tr>" >> $MRTGOutfile
echo -e "\t\t\t\t<td>System:</td>" >> $MRTGOutfile
echo -e "\t\t\t\t<td>$SysNm</td>" >> $MRTGOutfile
echo -e "\t\t\t</tr>" >> $MRTGOutfile
echo -e "\t\t\t<tr>" >> $MRTGOutfile
echo -e "\t\t\t\t<td>Administrator:</td>" >> $MRTGOutfile
echo -e "\t\t\t\t<td></td>" >> $MRTGOutfile
echo -e "\t\t\t</tr>" >> $MRTGOutfile
echo -e "\t\t\t<tr>" >> $MRTGOutfile
echo -e "\t\t\t\t<td>Description:</td>" >> $MRTGOutfile
echo -e "\t\t\t\t<td>CPU load</td>" >> $MRTGOutfile
echo -e "\t\t\t</tr>" >> $MRTGOutfile
echo -e "\t\t\t<tr>" >> $MRTGOutfile
echo -e "\t\t\t\t<td>Max:</td>" >> $MRTGOutfile
echo -e "\t\t\t\t<td>100%</td>" >> $MRTGOutfile
echo -e "\t\t\t</tr>" >> $MRTGOutfile
echo -e "\t\t</table>" >> $MRTGOutfile

echo "$SwitchIP"_cpu.html,"$SwitchIP"_cpu-day.png,CPU load >> $CSVFile
