#! /bin/sh
#############################################################################
# MRTGStatChecker.sh written by Michael Cole 2013/09/26 for Logiq3
# ---------------------------------------------------------------------------
# Purpose:
# This script will:
#    a. Inspect all *.cfg files and ensure there is an assoicated *.pid file.
#    b. Inspect all *.pid files and ensure there is an assoicated MRTG instance.
#    c. If <a.> fails, it will start MRTG against the CFG file.
#    d. If <b.> fails, it will delete the PID file and start MRTG against the CFG.
# ---------------------------------------------------------------------------
# Arguements:
# $0 = This script file name
# $1 = Location of MRTG CFG and PID files
# ---------------------------------------------------------------------------

if [ $# != 1 ] ; then
  echo "Usage: $0 <MRTG CFG/PID file location>"
  exit
fi

ScriptNameWPath=$0			# Read program name to meaningful variable
MRTGhome=$1				# Read MRTG CFG/PID home to meaningful variable
TmpDir=/tmp				# location of temporary files
MRTG=/usr/bin/mrtg			# MRTG instance assoicated with the MRTG user ID

NumDirs=`echo $ScriptNameWPath | awk -F/ '{print NF}'`
ScriptName=`echo $ScriptNameWPath | awk -F/ '{print $nf}' nf=$NumDirs`

Filelist=$TmpDir/$ScriptName.$$		# List of all Files to inspect
Processes=$TmpDir/$ScriptName.Proc.$$	# List of all running processes

# First lets verify that for every CFG there is a PID file, we need all CFG file names
ls -l $MRTGhome/*.cfg | awk '{print $9}' > $Filelist
ps aux > $Processes

LC=`wc -l $Filelist | awk '{print $1}'`

index=1
while (( index <= LC ))
do
  line=`head -n $index $Filelist | tail -n 1`
  # ASSERT: line will be the cfg file name.
  PIDFileWOExtension=`echo $line | awk -F. '{print $1}'`
  PIDFile=$PIDFileWOExtension".pid"
  if [ ! -e $PIDFile ] ; then
    # $PIDFile does not exist, we need to start an MRTG instance
    $MRTG $line &> /dev/null
    (( index += 1 ))
continue		# Don't want to process the PID becuase we already know it's been started
                        # and the PID file is based on what is now stale data.
  fi
  # ASSERT: IF MRTG is working and the CFG files are valid there is a PID file for every CFG file
  # Now we need to ensure there is a process for each PID
  #(mrtg might have crash and left a PID file behind)
  NumDirs=`echo $line | awk -F/ '{print NF}'`
  FileName=`echo $line | awk -F/ '{print $nf}' nf=$NumDirs`
  PID=`cat $PIDFile`
  LineNumAndPID=`cat $Processes | awk '{print $2}' | grep -n "$PID"`
  ProcLineNum=`echo $LineNumAndPID | awk -F: '{print $1}'`
  if [ ! -z "$ProcLineNum" ] ; then
    ProcLine=`head -n $ProcLineNum $Processes | tail -n 1`
    ProcArg=`echo $ProcLine | awk '{print $14}'`
  else
    ProcArg="dummy"
  fi
  NumDirs=`echo $ProcArg | awk -F/ '{print NF}'`
  ProcFile=`echo $ProcArg | awk -F/ '{print $nf}' nf=$NumDirs`
  if [ "$FileName" != "$ProcFile" ] ; then
    # ASSERT: CFG file name does not match the args passed into the Process with PID in the PID file
    # Need to delete invalid PID file and restart MRTG
    rm $PIDFile
    $MRTG $line &> /dev/null
  fi
  (( index += 1 ))
done

rm $Filelist
rm $Processes
