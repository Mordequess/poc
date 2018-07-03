#! /bin/sh
#############################################################################
# HTTPStest.sh written by Michael Cole 2013/11/05 for Logiq3
# ---------------------------------------------------------------------------
# Purpose:
# This script will generate the telnet commands required to test HTTPS
# on a remote host specified in the command lines args. I.e.
# $0 $1 | telnet.
# N.B. For this one test the name *MUST* resolve in DNS, add a host entry for
# local systems.
# ---------------------------------------------------------------------------
# Arguements:
# $0 = This script file name
# $1 = IP or DNS resolvable name of HTTPS server to verify.
# $2 - Master config file (or system list)
#############################################################################

if [ $# != 2 ] ; then
  echo "Usage: $0 <HTTPS Server Address or Name> <Master System List or Configuration File>"
  exit
fi

WordCount=`cat $2 | grep ^$1: | awk -F# '{print $2}' | awk '{print NF}'`
index=1
EXPR=""
while (( index <= WordCount ))
do
	Val=`cat $2 | grep ^$1 | awk -F# '{print $2}' | awk '{print $ind}' ind=$index`
	EXPR=`echo $Val | grep '^HTTPS:.*'`
	(( index += 1 ))
done

URI=`echo $EXPR | awk -F: '{print $2}'`
name=`echo $URI | awk -F@ '{print $2}'`
path=`echo $URI | awk -F@ '{print $1}'`

echo "s_client -connect $name:443"
sleep 3
echo "GET $path HTTP/1.0"
echo "host: $name"
echo
echo
# Seems that sometimes the first Head statement is not caught at the remote end
# lets send it three times.
sleep 3
echo "GET $path HTTP/1.0"
echo "host: $name"
echo
echo
sleep 2
# Third attempt
sleep 3
echo "GET $path HTTP/1.0"
echo "host: $name"
echo
echo
sleep 2
