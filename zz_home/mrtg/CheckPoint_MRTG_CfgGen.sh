#! /bin/sh
#############################################################################
# CheckPoint_MRTG_CfgGen.sh written by Michael Cole 2016/08/06 for Logiq3
# ---------------------------------------------------------------------------
# Purpose:
# This script will generate a configuration file for use by MRTG for
# monitoring CPU and memory.
# ---------------------------------------------------------------------------
# Arguements:
# $0 = This script file name
# $1 = IP address or DNS resolvable name of device to build config against
# $2 = Output MRTG configuration file
# $3 = DownPorts file (ignore this value)
# ---------------------------------------------------------------------------

if [ $# != 3 ] ; then
  echo "Usage: $0 <SwitchIP> <Output MRTG Cfg file> <disregard>"
  exit
fi

ScriptName=`echo $0 | awk -F/ '{print $NF}'`	# Read program name to meaningful variable
SwitchIP=$1					# Read Switch IP to meaningful variable
MRTGOutfile=$2					# Read output file name to meaningful variable
SNMPGET=/usr/bin/snmpget			# Prefered SNMPget command
SNMPWALK=/usr/bin/snmpwalk			# Prefered SNMPwalk command
MIBPATH=/usr/share/snmp/mibs			# Path to all SNMP MIBs
CheckPointMIB=$MIBPATH/R77.30_checkpoint.mib	# CheckPoint specific MIB
SNMPOptions="-m all -v 2c -c"			# Options for SNMPget/walk
SNMPCommunity="logiq3read"			# specify read community
VarLoc=4					# Output location from SNMPget of actual value
TmpDir=/tmp					# location of temporary files
MRTGHome=/home/mrtg				# Home directory of MRTG
quote=$'\042'					# This way can embed quotes in an echo, i.e. echo $quote abc $quote, returns " abc "
bang=$'\041'					# As with quotes above, enables us to embed an exclamation, !
HTML="`echo $MRTGOutfile | awk -F.cfg '{print $1}'`/power.html"

touch $3

# Next line will get the Switch name
SysNm=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP sysName.0 | awk '{print $vl}' vl=$VarLoc`

# First we build the HTML header
echo "<html>" > $HTML
echo "<"$bang"-- Begin Head -->" >> $HTML
echo -e "\t<head>" >> $HTML
echo -e "\t\t<title>$SysNm Checkpoint resource utilization</title>" >> $HTML
echo -e "\t\t<meta http-equiv="$quote"refresh"$quote" content="$quote"120"$quote" />" >> $HTML
echo -e "\t</head>" >> $HTML
echo "<"$bang"-- End Head Begin Body -->" >> $HTML
echo -e "\t<body bgcolor="$quote"#000000"$quote">" >> $HTML
echo -e "\t\t<font color="$quote"#ffffff"$quote">" >> $HTML
echo -e "\t\t<center>" >> $HTML

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
echo "LoadMIBs: $CheckPointMIB" >> $MRTGOutfile
echo >> $MRTGOutfile
echo >> $MRTGOutfile
echo >> $MRTGOutfile

MIB2Check="multiProcUsage"			# MIB to inspect (CPU utilization)
AvgCPU="procUsage"				# Average CPU utliziation accross all $MIB2Check

CPUCount=`$SNMPWALK $SNMPOptions $SNMPCommunity $SwitchIP $MIB2Check | wc -l`
index=1

while (( index <= CPUCount ))
do
  TargVal="$SwitchIP"_CPU$index
  echo "Target[$TargVal]: $MIB2Check.$index.0&$MIB2Check.$index.0:$SNMPCommunity@$SwitchIP" >> $MRTGOutfile
  echo "Unscaled[$TargVal]: ymwd" >> $MRTGOutfile
  echo "SetEnv[$TargVal]: MRTG_INT_IP=\"\" MRTG_INT_DESCR=\"Percent CPU utilization\"" >> $MRTGOutfile
  echo "MaxBytes[$TargVal]: 100" >> $MRTGOutfile
  echo "Title[$TargVal]: %CPU$index load" >> $MRTGOutfile
  echo "PageTop[$TargVal]: <h1>Percent CPU$index used</h1>" >> $MRTGOutfile
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
  echo -e "\t\t\t\t<td>Percent CPU utilization</td>" >> $MRTGOutfile
  echo -e "\t\t\t</tr>" >> $MRTGOutfile
  echo -e "\t\t\t<tr>" >> $MRTGOutfile
  echo -e "\t\t\t\t<td>Max:</td>" >> $MRTGOutfile
  echo -e "\t\t\t\t<td>100%</td>" >> $MRTGOutfile
  echo -e "\t\t\t</tr>" >> $MRTGOutfile
  echo -e "\t\t</table>" >> $MRTGOutfile
  echo -e "\t</div>" >> $MRTGOutfile
  echo -e "\n" >> $MRTGOutfile
  # Now lets fill in the HTML document
  echo "" >> $HTML
  echo -e "\t\tCPU: $index" >> $HTML
  echo -e "\t\t<br>Description: CPU $index utlization" >> $HTML
  echo -e "\t\t<br>" >> $HTML
  LowerTN=`echo $TargVal | awk '{print tolower($1)}'`
  echo -e "\t\t<A HREF="$quote"$LowerTN.html"$quote"><img src="$quote"$LowerTN-day.png"$quote"></A>" >> $HTML
  echo -e "\t\t<hr>" >> $HTML
  (( index += 1 ))
done

TargVal="$SwitchIP"_CPU
echo "Target[$TargVal]: $AvgCPU.0&$AvgCPU.0:$SNMPCommunity@$SwitchIP" >> $MRTGOutfile
echo "Unscaled[$TargVal]: ymwd" >> $MRTGOutfile
echo "SetEnv[$TargVal]: MRTG_INT_IP=\"\" MRTG_INT_DESCR=\"Percent CPU utilization\"" >> $MRTGOutfile
echo "MaxBytes[$TargVal]: 100" >> $MRTGOutfile
echo "Title[$TargVal]: Average %CPU load" >> $MRTGOutfile
echo "PageTop[$TargVal]: <h1>Average Percent CPU used</h1>" >> $MRTGOutfile
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
echo -e "\t\t\t\t<td>Average CPU utilization</td>" >> $MRTGOutfile
echo -e "\t\t\t</tr>" >> $MRTGOutfile
echo -e "\t\t\t<tr>" >> $MRTGOutfile
echo -e "\t\t\t\t<td>Max:</td>" >> $MRTGOutfile
echo -e "\t\t\t\t<td>100%</td>" >> $MRTGOutfile
echo -e "\t\t\t</tr>" >> $MRTGOutfile
echo -e "\t\t</table>" >> $MRTGOutfile
echo -e "\t</div>" >> $MRTGOutfile
echo -e "\n" >> $MRTGOutfile
# Now lets fill in the HTML document
echo "" >> $HTML
echo -e "\t\tAverage CPU" >> $HTML
echo -e "\t\t<br>Description: Average CPU utlization across all $CPUCount CPUs" >> $HTML
echo -e "\t\t<br>" >> $HTML
LowerTN=`echo $TargVal | awk '{print tolower($1)}'`
echo -e "\t\t<A HREF="$quote"$LowerTN.html"$quote"><img src="$quote"$LowerTN-day.png"$quote"></A>" >> $HTML
echo -e "\t\t<hr>" >> $HTML

MemReal=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP memTotalReal64.0 | awk '{print $vl}' vl=$VarLoc`

TargVal="$SwitchIP"_Mem
echo "Target[$TargVal]: memActiveReal64.0&memFreeReal64.0:$SNMPCommunity@$SwitchIP" >> $MRTGOutfile
echo "Unscaled[$TargVal]: ymwd" >> $MRTGOutfile
echo "SetEnv[$TargVal]: MRTG_INT_IP=\"\" MRTG_INT_DESCR=\"Percent Memory utilization\"" >> $MRTGOutfile
echo "MaxBytes[$TargVal]: $MemReal" >> $MRTGOutfile
echo "Title[$TargVal]: Memory: used and free" >> $MRTGOutfile
echo "LegendI[$TargVal]: Used memory:" >> $MRTGOutfile
echo "LegendO[$TargVal]: Free memory:" >> $MRTGOutfile
echo "PageTop[$TargVal]: <h1>Memory utilziation</h1>" >> $MRTGOutfile
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
echo -e "\t\t\t\t<td>Memory: used and free</td>" >> $MRTGOutfile
echo -e "\t\t\t</tr>" >> $MRTGOutfile
echo -e "\t\t\t<tr>" >> $MRTGOutfile
echo -e "\t\t\t\t<td>Max:</td>" >> $MRTGOutfile
echo -e "\t\t\t\t<td>$MemReal</td>" >> $MRTGOutfile
echo -e "\t\t\t</tr>" >> $MRTGOutfile
echo -e "\t\t</table>" >> $MRTGOutfile
echo -e "\t</div>" >> $MRTGOutfile
# Now lets fill in the HTML document
echo "" >> $HTML
echo -e "\t\tCPU usage" >> $HTML
echo -e "\t\t<br>Description: Memory in use" >> $HTML
echo -e "\t\t<br>" >> $HTML
LowerTN=`echo $TargVal | awk '{print tolower($1)}'`
echo -e "\t\t<A HREF="$quote"$LowerTN.html"$quote"><img src="$quote"$LowerTN-day.png"$quote"></A>" >> $HTML
echo -e "\t\t<hr>" >> $HTML
