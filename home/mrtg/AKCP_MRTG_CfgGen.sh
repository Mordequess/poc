#! /bin/sh
#############################################################################
# AKCP_MRTG_CfgGen.sh written by Michael Cole 2013/11/27 for Logiq3
# ---------------------------------------------------------------------------
# Purpose:
# This script will generate a configuration file for use by MRTG.
# In addition an index.html page will be generated with all sensor probe ports.
# This script will also generate a list of all ports currently offline.
# ---------------------------------------------------------------------------
# Arguements:
# $0 = This script file name
# $1 = IP address or DNS resolvable name of probe to build config against
# $2 = Output MRTG configuration file
# $3 = Output file name (will overwrite any existing) list of all ports currently down.
# ---------------------------------------------------------------------------

if [ $# != 3 ] ; then
  echo "Usage: $0 <SwitchIP> <Output MRTG Cfg file> <Output down ports file>"
  exit
fi

ScriptName=`echo $0 | awk -F/ '{print $NF}'`	# Read program name to meaningful variable
SwitchIP=$1					# Read Switch IP to meaningful variable
MRTGOutfile=$2					# Read output file name to meaningful variable
DownPrts=$3					# Read down ports file name to meaningful var
SNMPGET=/usr/bin/snmpget			# Prefered SNMPget command
SNMPWALK=/usr/bin/snmpwalk			# Prefered SNMPwalk command
MIBPATH=/usr/share/snmp/mibs			# Path to all SNMP MIBs
SNMPOptions="-m $MIBPATH/AKCP-MIB.txt -v 1 -c"	# Options for SNMPget/walk
SNMPCommunity="logiq3read"			# specify read community
VarLoc=4					# Output location from SNMPget of actual value
TmpDir=/tmp					# location of temporary files
quote=$'\042'					# This way can embed quotes in an echo, i.e. echo $quote abc $quote, returns " abc "
bang=$'\041'                                    # As with quotes above, enables us to embed an exclamation, !

HTML="`echo $MRTGOutfile | awk -F. '{print $1}'`/index.html"

# Next line will set NumIf to total number of interfaces (includes VLANs, Null0, etc.)
NumIf=`$SNMPWALK $SNMPOptions $SNMPCommunity $SwitchIP sensorProbeTempDegree | wc -l`
echo "Total Ports: $NumIf" > $DownPrts
# Next line will get the Switch name
SysNm=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP sysName.0 | awk -F\" '{print $2}' | tr ' ' '_'`

# First we build the HTML header
echo "<html>" > $HTML
echo "<"$bang"-- Begin Head -->" >> $HTML
echo -e "\t<head>" >> $HTML
echo -e "\t\t<title>$SysNm port list</title>" >> $HTML
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
echo "WorkDir: /home/mrtg/mrtg/$SysNm" >> $MRTGOutfile
echo "LoadMIBs: $MIBPATH/AKCP-MIB.txt" >> $MRTGOutfile
echo "Refresh: 300" >> $MRTGOutfile
echo "RunAsDaemon: yes" >> $MRTGOutfile
echo "Interval: 5" >> $MRTGOutfile
echo "Options[_]: noinfo, growright, gauge, nopercent" >> $MRTGOutfile
echo "MaxBytes[_]: 150" >> $MRTGOutfile
echo "YLegend[_]: Environmental Conditions" >> $MRTGOutfile
echo "ShortLegend[_]: degrees C or % RH" >> $MRTGOutfile
echo >> $MRTGOutfile

index=0					# loop counter
while (( index < NumIf ))
do
  IfOperStat=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP sensorProbeTempGoOnline.$index | awk '{print $VL}' VL=$VarLoc`
  IsDown=`echo $IfOperStat | grep goOffline`
  if [ -n "$IsDown" ] ; then
    # This Interface is down, document that it is down
    echo "Interface: $index is down" >> $DownPrts
    (( index += 1 ))
    continue
  fi
  # Now we need to add our interface to the config file.
  echo -e "\n" >> $MRTGOutfile
  LongDescription=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP sensorProbeTempDescription.$index | awk -F\" '{print $2}'`
  SubIndex=1
  NumTokens=`echo $LongDescription | awk '{print NF}'`
  SeenHyphen=0
  ShortDescription=""
  while (( SubIndex <= NumTokens ))
  do
	  # LongDescription looks like: Temperature - 3rd Floor
	  # We need to skip everything up and and including the hyphen.
	  Token=`echo $LongDescription | awk '{print $SI}' SI=$SubIndex`
	  if [ $SeenHyphen  -eq 1 ] && [ -n "$ShortDescription" ] ; then
		  ShortDescription="$ShortDescription"_$Token
	  elif [ $SeenHyphen  -eq 1 ] ; then
		  ShortDescription="$Token"
	  elif [ "$Token" = "-" ] ; then
		  SeenHyphen=1
	  fi
	  (( SubIndex += 1 ))
  done
  # At this point ShortDescription looks like: 3rd_Floor
  Model=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP spProductName.$index | awk -F\" '{print $2}' | awk '{print $1}'`
  # Model looks like: sensorProbe2
  TargetT="$ShortDescription"_"$Model"-"$index"T
  TargetH="$ShortDescription"_"$Model"-"$index"H
  SysAdmin=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP sysContact.0 | awk -F\" '{print $2}'`
  ShortDesWithSpace=`echo $ShortDescription | tr '_' ' '`
  TempHiCrit=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP sensorProbeTempHighCritical.$index | awk '{print $VL}' VL=$VarLoc`
  TempHiWarn=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP sensorProbeTempHighWarning.$index | awk '{print $VL}' VL=$VarLoc`
  TempLoWarn=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP sensorProbeTempLowWarning.$index | awk '{print $VL}' VL=$VarLoc`
  TempLoCrit=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP sensorProbeTempLowCritical.$index | awk '{print $VL}' VL=$VarLoc`
  HumidHiCrit=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP sensorProbeHumidityHighCritical.$index | awk '{print $VL}' VL=$VarLoc`
  HumidHiWarn=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP sensorProbeHumidityHighWarning.$index | awk '{print $VL}' VL=$VarLoc`
  HumidLoWarn=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP sensorProbeHumidityLowWarning.$index | awk '{print $VL}' VL=$VarLoc`
  HumidLoCrit=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP sensorProbeHumidityLowCritical.$index | awk '{print $VL}' VL=$VarLoc`
  # Build all the temperature monitoring for this interface
  echo "Target["$TargetT"]:sensorProbeTempDegree."$index"&sensorProbeTempDegree."$index":"$SNMPCommunity"@"$SwitchIP"" >> $MRTGOutfile
  echo "Title["$TargetT"]: Temperature "$ShortDesWithSpace"" >> $MRTGOutfile
  echo "PageTop["$TargetT"]:<H1>"$ShortDesWithSpace" "$Model" Temperature</H1>" >> $MRTGOutfile
  echo -e "\t<table>" >> $MRTGOutfile
  echo -e "\t\t<tr>" >> $MRTGOutfile
  echo -e "\t\t\t<td>System:</td>" >> $MRTGOutfile
  echo -e "\t\t\t<td>$Model</td>" >> $MRTGOutfile
  echo -e "\t\t</tr>" >> $MRTGOutfile
  echo -e "\t\t<tr>" >> $MRTGOutfile
  echo -e "\t\t\t<td>Administrator:</td>" >> $MRTGOutfile
  echo -e "\t\t\t<td>$SysAdmin</td>" >> $MRTGOutfile
  echo -e "\t\t</tr>" >> $MRTGOutfile
  echo -e "\t\t<tr>" >> $MRTGOutfile
  echo -e "\t\t\t<td>Temperature Thresholds are (from low critical to high critical)</td>" >> $MRTGOutfile
  echo -e "\t\t\t<td>Low: $TempLoCrit, Low warn: $TempLoWarn, High Warn: $TempHiWarn, High: $TempHiCrit</td>" >> $MRTGOutfile
  echo -e "\t\t</tr>" >> $MRTGOutfile
  echo -e "\t</table>" >> $MRTGOutfile
  echo -e "\n" >> $MRTGOutfile
  echo "" >> $HTML
  ShortWithSpace=`echo $ShortDescription | tr '_' ' '`
  echo -e "\t\t$ShortWithSpace Temperature" >> $HTML
  echo -e "\t\t<br>" >> $HTML
  LowerTN=`echo $TargetT | awk '{print tolower($1)}'`
  echo -e "\t\t<A HREF="$quote"$LowerTN.html"$quote"><img src="$quote"$LowerTN-day.png"$quote"></A>" >> $HTML
  echo -e "\t\t<hr>" >> $HTML
  # Build all the humidity monitoring for this interface
  echo "Target["$TargetH"]:sensorProbeHumidityPercent."$index"&sensorProbeHumidityPercent."$index":"$SNMPCommunity"@"$SwitchIP"" >> $MRTGOutfile
  echo "Title["$TargetH"]: Humidity "$ShortDesWithSpace"" >> $MRTGOutfile
  echo "PageTop["$TargetH"]:<H1>"$ShortDesWithSpace" "$Model" Humidity</H1>" >> $MRTGOutfile
  echo -e "\t<table>" >> $MRTGOutfile
  echo -e "\t\t<tr>" >> $MRTGOutfile
  echo -e "\t\t\t<td>System:</td>" >> $MRTGOutfile
  echo -e "\t\t\t<td>$Model</td>" >> $MRTGOutfile
  echo -e "\t\t</tr>" >> $MRTGOutfile
  echo -e "\t\t<tr>" >> $MRTGOutfile
  echo -e "\t\t\t<td>Administrator:</td>" >> $MRTGOutfile
  echo -e "\t\t\t<td>$SysAdmin</td>" >> $MRTGOutfile
  echo -e "\t\t</tr>" >> $MRTGOutfile
  echo -e "\t\t<tr>" >> $MRTGOutfile
  echo -e "\t\t\t<td>Humidity Thresholds are (from low critical to high critical)</td>" >> $MRTGOutfile
  echo -e "\t\t\t<td>Low: $HumidLoCrit, Low warn: $HumidLoWarn, High Warn: $HumidHiWarn, High: $HumidHiCrit</td>" >> $MRTGOutfile
  echo -e "\t\t</tr>" >> $MRTGOutfile
  echo -e "\t</table>" >> $MRTGOutfile
  echo -e "\n" >> $MRTGOutfile
  echo "" >> $HTML
  echo -e "\t\t$ShortWithSpace Humidity" >> $HTML
  echo -e "\t\t<br>" >> $HTML
  LowerTNH=`echo $TargetH | awk '{print tolower($1)}'`
  echo -e "\t\t<A HREF="$quote"$LowerTNH.html"$quote"><img src="$quote"$LowerTNH-day.png"$quote"></A>" >> $HTML
  echo -e "\t\t<hr>" >> $HTML
  (( index += 1 ))
done

echo -e "\t\t`date`" >> $HTML
echo "" >> $HTML
echo -e "\t\t</center>" >> $HTML
echo -e "\t\t</font color>" >> $HTML
echo -e "\t</body>" >> $HTML
echo "</html>" >> $HTML
