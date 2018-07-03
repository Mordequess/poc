#! /bin/sh
#############################################################################
# HTTPtest.sh written by Michael Cole 2013/10/30 for Logiq3
# ---------------------------------------------------------------------------
# Purpose:
# This script will generate the telnet commands required to test HTTP
# on a remote host specified in the command lines args. I.e.
# $0 $1 | telnet.
# ---------------------------------------------------------------------------
# Arguements:
# $0 = This script file name
# $1 = IP or DNS resolvable name of SMTP server to verify.
#############################################################################

if [ $# != 2 ] ; then
  echo "Usage: $0 <SMTP Server Address or Name> <Master System List or Configuration File>"
  exit
fi

WordCount=`cat $2 | grep ^$1: | awk -F# '{print $2}' | awk '{print NF}'`
if [ -e $WordCount ] ; then
	WordCount=0
fi
index=1
EXPR=""
while (( index <= WordCount ))
do
	 Val=`cat $2 | grep ^$1 | awk -F# '{print $2}' | awk '{print $ind}' ind=$index`
	 EXPR=`echo $Val | grep '^HTTP:.*'`
	 (( index += 1 ))
done

URI=`echo $EXPR | awk -F: '{print $2}'`
name=`echo $URI | awk -F@ '{print $2}'`
path=`echo $URI | awk -F@ '{print $1}'`

echo "open $name 80"
sleep 2
echo "HEAD $path HTTP/1.0"
echo "host: $name"
echo
echo
sleep 2
