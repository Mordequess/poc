#! /bin/sh
#############################################################################
# MRTGKillScript.sh written by Michael Cole 2013/09/26 for Logiq3
# ---------------------------------------------------------------------------
# Purpose:
# This script will ill all instances of MRTG
# ---------------------------------------------------------------------------
# Arguements:
# $0 = This script file name
# $1 = User Name running MRTG instances
# $2 - location of all MRTG cfg files
# ---------------------------------------------------------------------------

if [ $# != 2 ] ; then
  echo "Usage: $0 <MRTG user name> <MRTG cfg home>"
  exit
fi

ScriptNameWPath=$0			# Read program name to meaningful variable
MRTGUser=$1				# Read MRTG User name to meaningful variable
MRTGhome=$2				# Read MRTG CFG/PID home to meaningful variable
TmpDir=/tmp				# location of temporary files

NumDirs=`echo $ScriptNameWPath | awk -F/ '{print NF}'`
ScriptName=`echo $ScriptNameWPath | awk -F/ '{print $nf}' nf=$NumDirs`
ProcList=$TmpDir/$ScriptName.$$

CFGfileNames=`ls $MRTGhome/*.cfg`
ps U $MRTGUser | grep "$CFGfileNames" | grep perl > $ProcList
kill `cat $ProcList | awk '{print $1}'`
rm $ProcList
