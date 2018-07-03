#! /bin/sh
#############################################################################
# GenMRTGCfg.sh written by Michael Cole 2013/09/29 for Logiq3
# ---------------------------------------------------------------------------
# Purpose:
# This script will loop through all systems in the master configuration file.
# This script will call the appropriate MRTG configuration file generator.
# ---------------------------------------------------------------------------
# Arguements:
# $0 = This script file name
# $1 = The master configuration file.
#############################################################################

if [ $# != 1 ] ; then
  echo "Usage: $0 <Master Configuration file name and path>"
  exit
fi

SNMPGET=/usr/bin/snmpget			# Prefered SNMPget command
SNMPOptions="-v 2c -c"				# Options for SNMPget/walk
SNMPv1Options="-v 1 -c"				# Options for SNMPget/walk on version 1 devices
SNMPCommunity="logiq3read"			# specify read community
VarLoc=4                                	# Output location from SNMPget of actual value
TMPDIR=/tmp					# location of the temporary directory
MRTGHome=/home/mrtg				# location of MRTG Config generator scripts
ScriptsHome=/home/scripts			# Location of non-mrtg scripts
ScriptName=`echo $0 | awk -F/ '{print $NF}'`	# Read program name to meaningful variable
						# What if program is called with absoulte file location?
CfgFile=$1					# Read the config file name and path into meaningful variable
FileList=$TMPDIR/$ScriptName.$$			# list of all *.sh files in MRTG home
MRTGCfgHome=$MRTGHome/mrtg			# Home directory of MRTG cfg files
DownPortsHome=$ScriptsHome/DownMRTGPorts	# location of previous down
MRTG=/usr/bin/mrtg				# MRTG instance assoicated with the MRTG user ID
PowerGen=PoE_MRTG_CfgGen.sh			# MRTG config generator for monitoring PoE
CPUGen=CPU_MRTG_CfgGen.sh			# MRTG config generator for monitoring CPU
MEMGen=MEM_MRTG_CfgGen.sh			# MRTG config generator for monitoring Memory
HTMLGen=$MRTGHome/GenMRTGHTML.sh		# HTML power.html file generator

ls -l $MRTGHome/*.sh | awk '{print $9}' | awk -F/ '{print $NF}' > $FileList

CfgFileLen=`wc -l $CfgFile | awk '{print $1}'`
index=1
while (( index <= CfgFileLen ))
do
  line=`head -n $index $CfgFile | tail -n 1`
  # We need to ensure the line leads with an IP, otherwise skip.
  dummy=`echo $line | grep  '^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}'`
  if [ -z "$dummy" ] ; then
    # string does not lead with IP so we need to skip
    (( index += 1 ))
    continue
  fi
  # ASSERT: the line starts with an IP address
  # is there a devince in the line, we count colon delmited fields
  NumFields=`echo $line | awk -F: '{print NF}'`
  if (( NumFields == 1)) ; then
    # ASSERT: there is no colon on this line thus no tags to this IP
    (( index += 1 ))
    continue
  fi
  # ASSERT: there is at least one colon on this line after an IP address
  # Lets get the IP and go through each tag
  IPaddr=`echo $line | awk -F: '{print $1}'`
  SubIndex=2
  GenPowerHTML=0
  while (( SubIndex <= NumFields ))
  do
    # Many lines have comments after the tag, we need to ensure that we only capture
    # colon and space delimited data, then lower case it so we are case insensitve
    tag=`echo $line | awk -F: '{print $SI}' SI=$SubIndex | awk '{print $1}' | awk '{print tolower($0)}'`
    CfgGen=`cat $FileList | grep -i $tag`
    if [ ! -z "$CfgGen" ] ; then
      # $tag is a substring of Cfg Generator file name,
      # $CfgGen is the actual file name (without a path)
      # device name is the in the comments section
      if  [ "$tag" != "akcp" ] ; then
        # Device is NOT an AKCP
        name=`$SNMPGET $SNMPOptions $SNMPCommunity $IPaddr sysName.0 | awk '{print $VL}' VL=$VarLoc`
      else
	# Device is AKCP, which only supports SNMP ver. 1
	# In addition AKCP system names contain a space have to do all the below to correctly structure the name
	TokenIndex=$VarLoc
	name=""
	TokenCount=`$SNMPGET $SNMPv1Options $SNMPCommunity $IPaddr sysName.0 | awk '{print NF}'`
	while (( TokenIndex <= TokenCount ))
	do
		Token=`$SNMPGET $SNMPv1Options $SNMPCommunity $IPaddr sysName.0 | awk '{print $To}' To=$TokenIndex`
		if [ ! -z "$name" ] ; then
			name="$name"_"$Token"
		else
			name="$Token"
		fi
		(( TokenIndex += 1 ))
	done
      fi
      if [ $tag != "poe" ] && [ $tag != "cpu" ] && [ $tag != "mem" ] ; then
        $MRTGHome/$CfgGen $IPaddr $MRTGCfgHome/$name.cfg_new $DownPortsHome/$name.new
        # Before we overwrite an existing cfg file, lets kill the old MRTG instance
        PID=`cat $MRTGCfgHome/$name.pid`
        kill $PID
        mv $MRTGCfgHome/$name.cfg_new $MRTGCfgHome/$name.cfg
        $MRTG $MRTGCfgHome/$name.cfg &> /dev/null
        # If required this is where I ought to go through the downports list
        # and send a report. Currently there is no desire for this feature.
        mv $DownPortsHome/$name.new  $DownPortsHome/$name
      else
        ## Assert: $tag == poe || $tag == cpu || $tag == mem
        GenPowerHTML=1
        #  Need to generate a power, cpu or mem config here
	if [ $tag = "poe" ] ; then
          SysName="$name"Power
          $MRTGHome/$PowerGen $IPaddr $MRTGCfgHome/$SysName.cfg_new
        elif [ $tag = "cpu" ] ; then
          SysName="$name"CPU
          $MRTGHome/$CPUGen $IPaddr $MRTGCfgHome/$SysName.cfg_new
	else
	  ## ASSERT $tag == mem
          SysName="$name"MEM
          $MRTGHome/$MEMGen $IPaddr $MRTGCfgHome/$SysName.cfg_new
        fi
        # Before we overwrite an existing cfg file, lets kill the old MRTG instance
        PID=`cat $MRTGCfgHome/$SysName.pid`
        kill $PID
        mv $MRTGCfgHome/$SysName.cfg_new $MRTGCfgHome/$SysName.cfg
        $MRTG $MRTGCfgHome/$SysName.cfg &> /dev/null
      fi
    fi
    (( SubIndex += 1 ))
  done
  if (( GenPowerHTML == 1 )) ; then
    # Need to build the HTML for CPU, POW and memory here
    ToDay=`date +%F`
    CSVFile=$TMPDIR/$IPaddr.$ToDay
    $HTMLGen $CSVFile $name
    rm $CSVFile
  fi
  (( index += 1 ))
done

rm $FileList
