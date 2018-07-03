#! /bin/sh
#############################################################################
# CPU_MRTG_CfgGen.sh written by Michael Cole 2014/06/27 Logiq3
# ---------------------------------------------------------------------------
# Purpose:
# This script will generate a configuration file for use by MRTG for
# monitoring, memory use. A CSV of image location of daily graph and URL
# to full MRTG page will also be generated. (N.B. there are multiple
# memory instances, typically two or three, so there will be multiple graphs.)
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
TmpFile=$TmpDir/$ScriptName.$$			# Temp file for this script only
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

# First we need to count the total number of memory instances and get their SNMP index.
# FWIW, it appears routers use .1 as processor and .2 as I/O, but switches seem to have a third,
# around .16~.20 (driver text).
$SNMPWALK $SNMPOptions $SNMPCommunity $SwitchIP ciscoMemoryPoolName > $TmpFile
LineCount=`wc -l $TmpFile | awk '{print $1}'`
index=1
while (( index <= LineCount ))
do
	line=`head -n $index $TmpFile | tail -n 1`
	# Now lets get the unique index for each type of memory.
	SNMPindex=`echo $line | awk -F. '{print $2}' | awk '{print $1}'`
	MmNm=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP ciscoMemoryPoolName.$SNMPindex`
	MemName=`echo $MmNm | awk '{print $vl}' vl=$VarLoc | tr '/' '-'`
	# Now we need to total memory, seems the only way to get this is sum total free and
	# total used, I guess it never occured to anyone at Cisco we might want a theoretical max?
	# Eyes roll!
	UsdMm=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP ciscoMemoryPoolUsed.$SNMPindex`
	UsedMem=`echo $UsdMm | awk '{print $vl}' vl=$VarLoc`
	FrMm=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP ciscoMemoryPoolFree.$SNMPindex`
	FreeMem=`echo $FrMm | awk '{print $vl}' vl=$VarLoc`
	let Total=$UsedMem+$FreeMem
	# Now we can create the MRTG script with a "Max bytes" (total memory)
	TargVal="$SwitchIP"_MEM_$MemName
	# Getting MRTG to support MIB files is tricky (espcially since there are so many dependancies
	# among all the Cisco MIBs, so I'll just use the OID here.)
	echo -e "\n\n" >> $MRTGOutfile
	echo "Target[$TargVal]: 1.3.6.1.4.1.9.9.48.1.1.1.5.$SNMPindex&1.3.6.1.4.1.9.9.48.1.1.1.5.$SNMPindex:$SNMPCommunity@$SwitchIP" >> $MRTGOutfile
	echo "Unscaled[$TargVal]: ymwd" >> $MRTGOutfile
	echo "SetEnv[$TargVal]: MRTG_INT_IP=\"\" MRTG_INT_DESCR=\"Total $MemName Memory Utilization\"" >> $MRTGOutfile
	echo "MaxBytes[$TargVal]: $Total" >> $MRTGOutfile
	echo "Title[$TargVal]: $MemName Memory Utilization" >> $MRTGOutfile
	echo "PageTop[$TargVal]: <h1>Total $MemName Memory Used</h1>" >> $MRTGOutfile
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
	echo -e "\t\t\t\t<td>$MemName memory load</td>" >> $MRTGOutfile
	echo -e "\t\t\t</tr>" >> $MRTGOutfile
	echo -e "\t\t\t<tr>" >> $MRTGOutfile
	echo -e "\t\t\t\t<td>Max:</td>" >> $MRTGOutfile
	echo -e "\t\t\t\t<td>$Total</td>" >> $MRTGOutfile
	echo -e "\t\t\t</tr>" >> $MRTGOutfile
	echo -e "\t\t</table>" >> $MRTGOutfile

	# Need lower case for URLs
	LwrMemN=`echo $MemName | awk '{print tolower($1)}'`
	echo "$SwitchIP"_mem_$LwrMemN.html,"$SwitchIP"_mem_$LwrMemN-day.png,$MemName Memory load >> $CSVFile
	(( index += 1))
done

rm $TmpFile
