#! /bin/sh
#############################################################################
# GenHomePage.sh written by Michael Cole 2013/10/10 for Logiq3
# ---------------------------------------------------------------------------
# Purpose:
# This script will loop through all systems in the master configuration file.
# This script will then build the HTML home page for this monitoring system.
# ---------------------------------------------------------------------------
# Arguements:
# $0 = This script file name
# $1 = The master configuration file.
# ---------------------------------------------------------------------------
# Note, this script is to be called by GenMRTGCfg.sh
#############################################################################


SNMPGET=/usr/bin/snmpget			# Prefered SNMPget command
SNMPOptions="-v 2c -c"				# Options for SNMPget/walk
SNMPCommunity="logiq3read"			# specify read community
VarLoc=4                                	# Output location from SNMPget of actual value
TMPDIR=/tmp					# location of the temporary directory
MRTGHome=/home/mrtg				# location of MRTG Config generator scripts
ScriptsHome=/home/scripts			# Location of non-mrtg scripts
ScriptName=`echo $0 | awk -F/ '{print $NF}'`	# Read program name to meaningful variable
						# What if program is called with absoulte file location?
quote=$'\042'					# Required to embed quotes (") in output statements.
bang=$'\041'					# Required to embed exclimation points (!) in output statements
#GREEN="<img src="$quote"icons/green.png"$quote">"	# Green icon for status updates (not used)
GREEN="<img src="$quote"icons/green.gif"$quote">"	# Green icon for status updates
#RED="<img src="$quote"icons/red.png"$quote">"		# Red icon also for status updates (not used)
RED="<img src="$quote"icons/nb-red.gif"$quote">"	# Red icon also for status updates
YELLOW="<img src="$quote"icons/nb-yellow.gif"$quote">"	# Red icon also for status updates
PINGLOGCHK=$ScriptsHome/PingLog.sh		# Script that can inspect ping logs to see if system is up or down
SMTPLOGCHK=$ScriptsHome/SMTPLog.sh		# Script that can inspect SMTP logs to see if system is up or down
HTTPLOGCHK=$ScriptsHome/HTTPLog.sh		# Script that can inspect HTTP logs to see if system is up or down
HTTPSLOGCHK=$ScriptsHome/HTTPSLog.sh		# Script that can inspect HTTPS logs to see if system is up or down
AKCPLOGCHK=$ScriptsHome/AKCPLog.sh		# Script that can inspect AKCP logs to see if system is within desired environmental

if [ $# != 1 ] ; then
  echo "Usage: $0 <Master Configuration file name and path>"
  exit
fi
CfgFile=$1					# Read the config file name and path into meaningful variable

function GENHTML {
  #######################################################################
  # Purpose: Convert ordered list code in HTML table row.
  # ---------------------------------------------------------------------
  # Arguements:
  # $1 - input, ordered list code, as specified by BuildTableRow comments.
  # $2 - input, IP address of monitoried host
  # $3 - output, HTML table row.
  #######################################################################
  val=$1
  counter=128
  TempFile=$TMPDIR/FUNCTION_GENHTML.$$
  SystemName=""
  IPaddr="$2"

  echo -e "\t\t\t</tr>" >> $3
  while (( counter > 0 ))
  do
    string="\t\t\t\t<td align="$quote"centre"$quote" valign="$quote"center"$quote">"
    if (( val >= counter )) ; then
      ## XXX BUGBUG XXX
      ## Need to embed logic here for DNS.
      ## XXX BUGBUG XXX
      if (( counter == 128 )) ; then
	## ASSERT we are in the AKCP
	AKCPStat=`$AKCPLOGCHK $IPaddr`
	EnvStatus=`echo $AKCPStat | awk -F, '{print $2}'`
	SysName=`echo $AKCPStat | awk -F, '{print $1}'`
	case $EnvStatus in
		GREEN)
		  string=""$string"<A HREF="$quote"mrtg/$SysName/"$quote">$GREEN</A></td>"
		  ;;
	 	YELLOW)
		  string=""$string"<A HREF="$quote"mrtg/$SysName/"$quote">$YELLOW</A></td>"
		  ;;
	 	RED)
		  string=""$string"<A HREF="$quote"mrtg/$SysName/"$quote">$RED</A></td>"
		  ;;
		*)
		  echo "AKCPLog.sh returned an invalid return value"
		  exit 1
		  ;;
	esac
      elif (( counter == 16 )) ; then
        ## ASSERT we are in the MRTG column and there is a valid entry
        SystemName=`$SNMPGET $SNMPOptions $SNMPCommunity $IPaddr sysName.0 | awk '{print $vl}' vl=$VarLoc`
        string=""$string"<A HREF="$quote"mrtg/$SystemName/"$quote">$GREEN</A></td>"
      elif (( counter == 1 )) ; then
	## ASSERT this is a ping check (note, SystemStat==0 --> System is UP)
	SystemStat=`$PINGLOGCHK $IPaddr`
	string=""$string"<A HREF="$quote"PingHistory/"$IPaddr"_hist.html"$quote">"
	if (( SystemStat == 0 )) ; then
	  string=""$string""$GREEN"</A></td>"
	elif (( SystemStat == 2 )) ; then
	  string=""$string""$YELLOW"</A></td>"
	else
	  string=""$string""$RED"</A></td>"
	fi
      elif (( counter == 8 )) ; then
	## ASSERT this is a SMTP check
	## SMTPStat==0 --> System is answering 200 OK to SMTP connection requests
	SMTPStat=`$SMTPLOGCHK $IPaddr`
	string=""$string"<A HREF="$quote"SMTPHistory/"$IPaddr"_hist.html"$quote">"
	if (( SMTPStat == 0 )) ; then
	  string=""$string""$GREEN"</A></td>"
	elif (( SMTPStat == 2 )) ; then
	  string=""$string""$YELLOW"</A></td>"
	else
	  string=""$string""$RED"</A></td>"
	fi
      elif (( counter == 32 )) ; then
	## AASERT this is a HTTP check
	## HTTPStat==0 --> System is responding to HTTP head requests
	HTTPStat=`$HTTPLOGCHK $IPaddr`
	string=""$string"<A HREF="$quote"HTTPHistory/"$IPaddr"_hist.html"$quote">"
	if (( HTTPStat == 0 )) ; then
	  string=""$string""$GREEN"</A></td>"
	elif (( HTTPStat == 2 )) ; then
	  string=""$string""$YELLOW"</A></td>"
	else
	  string=""$string""$RED"</A></td>"
	fi
      elif (( counter == 64 )) ; then
	## AASERT this is a HTTPS check
	## HTTPSStat==0 --> System is responding to HTTPS head requests
	HTTPSStat=`$HTTPSLOGCHK $IPaddr`
	string=""$string"<A HREF="$quote"HTTPSHistory/"$IPaddr"_hist.html"$quote">"
	if (( HTTPSStat == 0 )) ; then
	  string=""$string""$GREEN"</A></td>"
	elif (( HTTPSStat == 2 )) ; then
	  string=""$string""$YELLOW"</A></td>"
	else
	  string=""$string""$RED"</A></td>"
	fi
      elif (( counter == 4 )) ; then
	## ASSERT this is a PoE check
        SystemName=`$SNMPGET $SNMPOptions $SNMPCommunity $IPaddr sysName.0 | awk '{print $vl}' vl=$VarLoc`
        string=""$string"<A HREF="$quote"mrtg/$SystemName/power.html"$quote">$GREEN</A></td>"
      else
        string=""$string"X</td>"
      fi
      (( val -= counter ))
    else
      string=""$string"-</td>"
    fi
    echo -e $string | cat - $3 > $TempFile && mv $TempFile $3
    counter=`expr $counter / 2`
  done
  if [ -e $SystemName ] ; then
     SystemName=`cat $CfgFile | grep -m 1 ^$IPaddr: | awk -F# '{print $2}' | awk '{print $1}'`
  fi
  if [ -e $SystemName ] ; then
    # Although the Statement above should set the system name it is possible there isn't one in the cfg file
    # lets handle that possiblity here
    string="\t\t\t<tr>\n\t\t\t\t<td align="$quote"centre"$quote" valign="$quote"center"$quote">$IPaddr</td>";
  else
    string="\t\t\t<tr>\n\t\t\t\t<td align="$quote"centre"$quote" valign="$quote"center"$quote">$SystemName ($IPaddr)</td>";
  fi
  echo -e $string | cat - $3 > $TempFile && mv $TempFile $3

} #################### END GENHTML

function BuildTableRow {
  #######################################################################
  # Purpose: Convert one sever entry into an ordered list code.
  #          i.e. Ping = 1, dns = 2, http = 4, so an HTTP server = 5.
  #          Pass this on to other functions to build HTML for one
  #          table row.
  # ---------------------------------------------------------------------
  # Arguements:
  # $1 - input, single sever entry from the Master Config file.
  #      includes full line, i.e. <IPaddr>:<item2>:<item1>:<item4>
  # $2 - output, will be generated by downstream functions. Will use
  #      the following sequence, (in order):
  #      * ping (is pingable, 1)
  #      * dns (runs a dns server, 2)
  #      * PoE (runs a PoE switch, 4)
  #      * smtp (runs a smtp server, 8)
  #      * mrtg (has extensive mrtg graphs to link to, 16)
  #      * http (runs a http server, 32)
  #      * https (runs a SSL HTTP server, 64)
  #      * environmental (AKCP mrtg graphs, typical temp/humidity, 128)
  #######################################################################
  NumFields=`echo $1 | awk -F: '{print NF}'`
  IP=`echo $1 | awk -F: '{print $1}'`
  Index=2
  val=0
  SetPoE=0
  while (( Index <= NumFields ))
  do
    # Many lines have comments after the tag, we need to ensure that we only capture
    # colon and space delimited data, then lower case it so we are case insensitve
    tag=`echo $1 | awk -F: '{print $I}' I=$Index | awk '{print $1}' | awk '{print tolower($0)}'`
    # We need to add an entry to our page for this tag
    case $tag in
      ping)
        ((val += 1))
        ;;
      dns)
        ((val += 2))
        ;;
      poe | cpu | mem | checkpoint )
        if (( SetPoE == 0 )) ; then
          ((val += 4))
        fi
	SetPoE=1
        ;;
      smtp)
        ((val += 8))
        ;;
      cisco1841|cat3560|juniperex2200|cat3750)
        ((val += 16))
        ;;
      http)
        ((val += 32))
        ;;
      https)
        ((val += 64))
        ;;
      akcp)
        ((val += 128))
	;;
      relay)
        ((val += 0))
        ## This tag does exist, but is only used to demark the relay server
        ## used by this system and should be ignored.
        ;;
      *)
        echo "The tag value $tag is unrecognized"
        exit 1
        ;;
    esac
    (( Index += 1 ))
  done
  GENHTML $val $IP $2

} #################### END BuildTableRow

###################### Start MAIN

HTML=$TMPDIR/$ScriptName.$$		# HTML output file, will have to be moved
DATE=`date`				# Start time of script
IMG="http://www.logiq3.com/Portals/146511/images/logiq3-logo.png"

SysIP=`cat $CfgFile | grep System_Monitor_Server | awk -F: '{print $1}'`

# First we build the HTML header
echo "<html>" > $HTML
echo "<"$bang"-- Begin Head -->" >> $HTML
echo -e "\t<head>" >> $HTML
echo -e "\t\t<title>System Monitor Home Page</title>" >> $HTML
echo -e "\t\t<meta http-equiv="$quote"refresh"$quote" content="$quote"120;URL=http://$SysIP/"$quote" />" >> $HTML
echo -e "\t</head>" >> $HTML
echo "<"$bang"-- End Head Begin Body -->" >> $HTML
echo -e "\t<body bgcolor="$quote"#FAFAFA"$quote">" >> $HTML
echo -e "\t\t<table width="$quote"100%"$quote">" >> $HTML
echo -e "\t\t\t<tr>" >> $HTML
echo -e "\t\t\t\t<td align="$quote"left"$quote" valign="$quote"bottom"$quote">$DATE</td>" >> $HTML
echo -e "\t\t\t\t<td></td><td></td><td></td><td></td><td></td><td></td><td></td>" >> $HTML
echo -e "\t\t\t\t<td align="$quote"center"$quote" valign="$quote"center"$quote"><img src=$IMG></td>" >> $HTML
echo -e "\t\t\t</tr><tr></tr><tr>" >> $HTML
echo -e "\t\t\t\t<td></td><td>Ping</td><td>DNS</td><td>System Resources</td><td>SMTP</td><td>MRTG</td><td>HTTP</td><td>HTTPS</td><td>ENVIRONMENTAL</td>" >> $HTML
echo -e "\t\t\t</tr>" >> $HTML


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
  ValsOnly=`echo $line | awk '{print $1}'` # Get rid of everything after the first white space
  HTMLLine=$TMPDIR/HTMLline.$$
  BuildTableRow $ValsOnly $HTMLLine
  cat $HTMLLine >> $HTML
  rm $HTMLLine
  (( index += 1 ))
done

echo -e "\t\t</table>" >> $HTML
echo -e "<br>\n<hr>\n<br>" >> $HTML
echo -e "\t\t<table width="$quote"100%"$quote">" >> $HTML
echo -e "\t\t\t<tr>" >> $HTML
echo -e "\t\t\t\t<td></td><td align="$quote"center"$quote">LEGEND</td><td></td>" >> $HTML
echo -e "\t\t\t</tr>\n\t\t\t<tr>" >> $HTML
echo -e "\t\t\t\t<td align="$quote"center"$quote">Green (nominal) - $GREEN</td>" >> $HTML
echo -e "\t\t\t\t<td align="$quote"center"$quote">Yellow (warning) - $YELLOW</td>" >> $HTML
echo -e "\t\t\t\t<td align="$quote"center"$quote">Red (alert) - $RED</td>" >> $HTML
echo -e "\t\t\t</tr>" >> $HTML
echo -e "\t\t</table>" >> $HTML
echo -e "\t</body>" >> $HTML
echo "</html>" >> $HTML

mv -f $HTML /var/www/html/index.html
chcon -v --type=httpd_sys_content_t /var/www/html/index.html > /dev/null
