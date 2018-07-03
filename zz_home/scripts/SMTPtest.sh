#! /bin/sh
#############################################################################
# SMTPtest.sh written by Michael Cole 2013/09/05 for Logiq3
# ---------------------------------------------------------------------------
# Purpose:
# This script will generate the telnet commands required to test SMTP
# on a remote host specified in the command lines args. I.e.
# $0 $1 | telnet.
# ---------------------------------------------------------------------------
# Arguements:
# $0 = This script file name
# $1 = IP or DNS resolvable name of SMTP server to verify.
#############################################################################

if [ $# != 1 ] ; then
  echo "Usage: $0 <SMTP Server Address or Name>"
  exit
fi

echo "open $1 25"
sleep 2
echo "helo"
echo quit
echo
sleep 2
