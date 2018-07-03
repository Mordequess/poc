#! /bin/sh
#############################################################################
# Cat3750_MRTG_CfgGen.sh written by Michael Cole 2013/08/19 for Logiq3
# ---------------------------------------------------------------------------
# Purpose:
# This script will generate a configuration file for use by MRTG.
# In addition an index.html page will be generated with all switch ports.
# This script will also generate a list of all ports currently offline.
# ---------------------------------------------------------------------------
# Arguements:
# $0 = This script file name
# $1 = IP address or DNS resolvable name of switch to build config against
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
SNMPOptions="-v 2c -c"				# Options for SNMPget/walk
SNMPCommunity="logiq3read"			# specify read community
VarLoc=4					# Output location from SNMPget of actual value
TmpDir=/tmp					# location of temporary files
DescWalkFile=$TmpDir/$ScriptName.$$		# SNMPwalk of ifDescr will be dumped to DescWalkFile
IfType2Skip="Null Vlan Stack"			# Space demlimited list of all types of interfaces we won't put in our MRTG config file
quote=$'\042'					# This way can embed quotes in an echo, i.e. echo $quote abc $quote, returns " abc "
bang=$'\041'					# As with quotes above, enables us to embed an exclamation, !
HTML="`echo $MRTGOutfile | awk -F.cfg '{print $1}'`/index.html"

# Next line will set NumIf to total number of interfaces (includes VLANs, Null0, etc.)
NumIf=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP ifNumber.0 | awk '{print $VL}' VL=$VarLoc`
echo "Total Ports: $NumIf" > $DownPrts
# Next line will get the Switch name
SysNm=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP sysName.0 | awk '{print $VL}' VL=$VarLoc`

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
echo "RunAsDaemon: Yes" >> $MRTGOutfile
echo "Interval: 5" >> $MRTGOutfile
echo >> $MRTGOutfile

$SNMPWALK $SNMPOptions $SNMPCommunity $SwitchIP ifDescr > $DescWalkFile
LineCount=`wc -l $DescWalkFile | awk '{print $1}'`

index=1					# loop counter
while (( index <= LineCount ))
do
  # Next line will set Descript to interface description (we want to skip VLANs, Null0)
  line=`head -n $index $DescWalkFile | tail -n 1`
  Descript=`echo $line | awk '{print $VL}' VL=$VarLoc`
  # Need the SNMP interface ID number, typically >10000, but seems somewhat random.
  SNMPIfNum=`echo $line | awk '{print $1}' | awk -F. '{print $2}'`
  NumTypesToSkip=`echo $IfType2Skip | awk '{print NF}'`
  SubIndex=1
  # Need to ensure that whatever this interface is, FastEther, GigabitEther, Ether, etc. is not a substring of something in the
  # list of interfaces to skip. Have to build this ugly inner loop to check substring matches.
  while (( SubIndex <= NumTypesToSkip))
  do
    If2Skip=`echo $IfType2Skip | awk '{print $SI}' SI=$SubIndex`
    SkipNotNull=`echo $Descript | grep $If2Skip`
    if [ -n "$SkipNotNull" ] ; then
      # SkipNotNull NOT empty - that means we should skip this interface. Lets exit this loop.
      SubIndex=$NumTypesToSkip
    fi
    (( SubIndex += 1))
  done
  if [ -n "$SkipNotNull" ] ; then
    # We will take a pass on this interface, it's in the skip list.
    (( index += 1 ))
    continue
  fi
  # ASSERT: At this point in our loop we know the interface is NOT in the skip list, lets see if it is acutally up.
  IfOperStat=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP ifOperStatus.$SNMPIfNum | awk '{print $VL}' VL=$VarLoc`
  IsDown=`echo $IfOperStat | grep down`
  if [ -n "$IsDown" ] ; then
    # This Interface is down, document that it is down
    echo "Interface: $Descript at $SNMPIfNum is down" >> $DownPrts
  fi
  # Now we need to add our interface to the config file.
  echo -e "\n" >> $MRTGOutfile
  FileFriendDescript=`echo $Descript | tr '/' '-'`
  TargName="$SwitchIP"_"$FileFriendDescript"
  OperSpeed=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP ifSpeed.$SNMPIfNum | awk '{print $VL}' VL=$VarLoc`
  if (( $OperSpeed >= 10000000000 )) ; then
    # Speed is greater, or equal to, 10G
    let IfSpeed=OperSpeed/1000000000
    IfSpeed="$IfSpeed"Gbps
  elif (( $OperSpeed >= 10000000 )) ; then
    # 10G > Speed >= 10M
    let IfSpeed=OperSpeed/1000000
    IfSpeed="$IfSpeed"Mbps
  elif (( $OperSpeed >= 1000 )) ; then
    # 10M > Speed >= 1K
    let IfSpeed=OperSpeed/1000
    IfSpeed="$IfSpeed"Kbps
  else
    # Speed less than 1Kbps
    IfSpeed="$OperSpeed"bps
  fi
  let OpSpeedBytes=OperSpeed/8
  Maintainer=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP sysContact.0 | awk '{print $VL}' VL=$VarLoc`
  IfType=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP ifType.$SNMPIfNum | awk '{print $VL}' VL=$VarLoc`
  ShrtNm=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP ifName.$SNMPIfNum | awk '{print $VL}' VL=$VarLoc`
  ConfigDescript=`$SNMPGET $SNMPOptions $SNMPCommunity $SwitchIP ifAlias.$SNMPIfNum | awk -F: '{print $VL}' VL=$VarLoc`
  if (( $OperSpeed >= 100000000 )) ; then
    # Speed >= 100M, use 64 bit counters
    echo "Target[$TargName]: ifHCInOctets.$SNMPIfNum&ifHCOutOctets.$SNMPIfNum:$SNMPCommunity@$SwitchIP:::::2" >> $MRTGOutfile
  else
    echo "Target[$TargName]: $SNMPIfNum:$SNMPCommunity@$SwitchIP:::::2" >> $MRTGOutfile
  fi
  echo "SetEnv[$TargName]: MRTG_INT_IP=$quote$quote MRTG_INT_DESCR=$quote$Descript$quote" >> $MRTGOutfile
  echo "MaxBytes[$TargName]: $OpSpeedBytes" >> $MRTGOutfile
  echo "Title[$TargName]: $Descript -- $SysNm" >> $MRTGOutfile
  echo "PageTop[$TargName]: <h1>$Descript -- $SysNm</h1>" >> $MRTGOutfile
  echo -e "\t<div id="$quote"sysdetails$quote>\n\t\t<table>" >> $MRTGOutfile
  echo -e "\t\t\t<tr>\n\t\t\t\t<td>System:</td>\n\t\t\t\t<td>$SysNm</td>\n\t\t\t</tr>" >> $MRTGOutfile
  echo -e "\t\t\t<tr>\n\t\t\t\t<td>Administrator:</td>\n\t\t\t\t<td>$Maintainer</td>\n\t\t\t</tr>" >> $MRTGOutfile
  echo -e "\t\t\t<tr>\n\t\t\t\t<td>Description:</td>\n\t\t\t\t<td>$SysNm Interface: $Descript</td>\n\t\t\t</tr>" >> $MRTGOutfile
  echo -e "\t\t\t<tr>\n\t\t\t\t<td>Interface Type:</td>\n\t\t\t\t<td>$IfType</td>\n\t\t\t</tr>" >> $MRTGOutfile
  echo -e "\t\t\t<tr>\n\t\t\t\t<td>Short Name:</td>\n\t\t\t\t<td>$ShrtNm</td>\n\t\t\t</tr>" >> $MRTGOutfile
  echo -e "\t\t\t<tr>\n\t\t\t\t<td>Max Speed:</td>\n\t\t\t\t<td>$IfSpeed</td>\n\t\t\t</tr>" >> $MRTGOutfile
  echo -e "\t\t\t<tr>\n\t\t\t\t<td>Configuration Description:</td>\n\t\t\t\t<td>$ConfigDescript</td>\n\t\t\t</tr>" >> $MRTGOutfile
  echo -e "\t\t</table>\n\t</div>" >> $MRTGOutfile
  # Now lets fill in the HTML document
  echo "" >> $HTML
  echo -e "\t\tPort: $ShrtNm" >> $HTML
  NoSpace=$(sed -e 's/^[[:space:]]*//' <<< $ConfigDescript )
  if [ "$NoSpace" != "" ] ; then
    echo -e "\t\t<br>Description (if available): $NoSpace" >> $HTML
  fi
  echo -e "\t\t<br>" >> $HTML
  LowerTN=`echo $TargName | awk '{print tolower($1)}'`
  echo -e "\t\t<A HREF="$quote"$LowerTN.html"$quote"><img src="$quote"$LowerTN-day.png"$quote"></A>" >> $HTML
  echo -e "\t\t<hr>" >> $HTML
  (( index += 1 ))
done

echo -e "\t\t`date`" >> $HTML
echo "" >> $HTML
echo -e "\t\t</center>" >> $HTML
echo -e "\t\t</font color>" >> $HTML
echo -e "\t</body>" >> $HTML
echo "</html>" >> $HTML

rm  $DescWalkFile
