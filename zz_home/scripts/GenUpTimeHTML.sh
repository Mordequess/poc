#! /bin/sh
#############################################################################
# GenUpTimeHTML.sh written by Michael Cole 2013/12/19 for Logiq3
# ---------------------------------------------------------------------------
# Purpose:
# This script will read in a command line specified *hist.txt file and compute:
# Total down time, total uptime and percent uptime.
# This script will also provide uptime stats for weekly, monthly and annual, if
# available. This script will read in the nature of the uptime, Ping, HTTP(S), SMTP.
# from the command line and generate an HTML summary of data from
# the hist.txt file. The HTML file will be placed in the appropraite subdirectory
# of /var/www with a name in the form *hist.html (the same as the first parameter
# but with an HTML instead of TXT file extension.)
# ---------------------------------------------------------------------------
# Arguements:
# $0 = This script file name
# $1 = The historical date file in plain text
# $2 = The type of uptime, i.e. Ping, HTTP, HTTPS or SMTP
# ---------------------------------------------------------------------------

if [ $# != 2 ] ; then
	echo "Usage: $0 <historical data file> <data file type, ping, http, https, smtp>"
  exit
fi

ScriptName=`echo $0 | awk -F/ '{print $NF}'`		# Read program name to meaningful variable
HistDataFile=$1						# Read the historical data file name to a meaningful variable
DatFileClass=`echo $2 | awk '{print tolower($1)}'`	# Read the class of data into a meanfingful variable
TmpDir=/tmp						# Location of the temp directory
TmpHTML=$TmpDir/$ScriptName-$$.html			# Temporary HTML file
quote=$'\042'						# This way can embed quotes in an echo, i.e. echo $quote abc $quote, returns " abc "
bang=$'\041'                                    	# As with quotes above, enables us to embed an exclamation, !
WWWHome=/var/www					# Home directory of all web content
SecondsPerWeek=604800					# 60 * 60 * 24 * 7 (i.e. sec/min * m/hr * hr/day * d/week)
SecondsPerMonth=2592000					# As above 60*60*24*30 (assume 30 days/month)
SecondsPerYear=31536000					# As above 60*60*24*365 (assume all years are 365 days)

## First we need to build the output file name, which is acutally difficult, first we need to
## remove a file extension from a file that likely starts with an IP address in dotted decimal notation.
## Thus 127.0.0.1_hist.txt must be converted to 127.0.0.1_hist (that is what the loop below takes care of)

FNindex=2
NoExtension=`echo $HistDataFile | awk -F. '{print $1}'`
FNdotCount=`echo $HistDataFile | awk -F. '{print NF}'`
while (( FNindex < FNdotCount ))
do
	token=`echo $HistDataFile | awk -F. '{print $FNI}' FNI=$FNindex`
	NoExtension="$NoExtension.$token"
	(( FNindex += 1 ))
done

HTML="$NoExtension.html"

## We do not need to figure out the correct path for the file as the *Log.sh file
## gives us the full path, in $2, when it calls this script. We simply need to replace,
## .txt with .html.

## Now lets gather some statistics and generate the meat of our HTML document.
## We will insert the data gathered below into the middle of our HTML document,
## so for now lets just dump everything into a temporary file.

FileLen=`wc -l $HistDataFile | awk '{print $1}'`
TotalDownTime=0
TotalUpTime=0
WeeklyDownTime=0
WeeklyUpTime=0
MonthlyUpTime=0
MonthlyDownTime=0
YearlyUpTime=0
YearlyDownTime=0
RealTime=`date +%s`
let WeekBeforeReal=$RealTime-$SecondsPerWeek
let MonthBeforeReal=$RealTime-$SecondsPerMonth
let YearBeforeReal=$RealTime-$SecondsPerYear
line=`head -n 1 $HistDataFile | tail -n 1`	# Read in the first line (eliminate a base case)
PrvStatus=`echo $line | awk -F, '{print $1}'`
PrvDate=`echo $line | awk -F, '{print $2}'`
PrvDateInSec=`date +%s -d "$PrvDate"`
InitialDateInSec=$PrvDateInSec
index=2
while (( index <= FileLen ))
do
	line=`head -n $index $HistDataFile | tail -n 1`
	CurStatus=`echo $line | awk -F, '{print $1}'`
	CurDate=`echo $line | awk -F, '{print $2}'`
	CurDateInSec=`date +%s -d "$CurDate"`
	let ElapsedTime=$CurDateInSec-$PrvDateInSec
	if [ "$CurDateInSec" -gt "$WeekBeforeReal" ] ; then
		# Assert, CurDateInSec is less than 7 days ago
		# We need to sum everything over the past 7 days, could be one event, could be many,
		# What if there is not 7 days of history?
		if [ "$WeeklyDownTime" != 0 ] || [ "$WeeklyUpTime" != 0 ] || [ "$PrvDateInSec" -lt "$WeekBeforeReal" ] ; then
			# Assert the logs go back at least one week. (We already know the CurDate is less than 7 days ago.)
			if [ "$PrvStatus" = "UP" ] ; then
				if [ "$PrvDateInSec" -lt "$WeekBeforeReal" ] ; then
					# The previous date was more than a week ago
					let WeeklyUpTime=$CurDateInSec-$WeekBeforeReal
				else
					# The previous date was less than a week ago
					let WeeklyUpTime=$WeeklyUpTime+$ElapsedTime
				fi
			else
				# Assert PrvStatus = DOWN
				if [ "$PrvDateInSec" -lt "$WeekBeforeReal" ] ; then
					# The previous date was more than a week ago
					let WeeklyDownTime=$CurDateInSec-$WeekBeforeReal
				else
					# The previous date was less than a week ago
					let WeeklyDownTime=$WeeklyDownTime+$ElapsedTime
				fi
			fi
		fi
	fi
	if [ "$CurDateInSec" -gt "$MonthBeforeReal" ] ; then
		# Assert, CurDateInSec is less than 30 days ago
		# We need to sum everything over the past 30 days, could be one event, could be many,
		# What if there is not 30 days of history?
		if [ "$MonthlyDownTime" != 0 ] || [ "$MonthlyUpTime" != 0 ] || [ "$PrvDateInSec" -lt "$MonthBeforeReal" ] ; then
			# Assert the logs go back at least 30 days. (We already know the CurDate is less than 30 days ago.)
			if [ "$PrvStatus" = "UP" ] ; then
				if [ "$PrvDateInSec" -lt "$MonthBeforeReal" ] ; then
					# The previous date was more than 30 days ago
					let MonthlyUpTime=$CurDateInSec-$MonthBeforeReal
				else
					# The previous date was less than a month ago
					let MonthlyUpTime=$MonthlyUpTime+$ElapsedTime
				fi
			else
				# Assert PrvStatus = DOWN
				if [ "$PrvDateInSec" -lt "$MonthBeforeReal" ] ; then
					# The previous date was more than a week ago
					let MonthlyDownTime=$CurDateInSec-$MonthBeforeReal
				else
					# The previous date was less than a week ago
					let MonthlyDownTime=$MonthlyDownTime+$ElapsedTime
				fi
			fi
		fi
	fi
	if [ "$CurDateInSec" -gt "$YearBeforeReal" ] ; then
		# Assert, CurDateInSec is less than 365 days ago
		# We need to sum everything over the past 365 days, could be one event, could be many,
		# What if there is not 365 days of history?
		if [ "$YearlyDownTime" != 0 ] || [ "$YearlyUpTime" != 0 ] || [ "$PrvDateInSec" -lt "$YearBeforeReal" ] ; then
			# Assert the logs go back at least one year. (We already know the CurDate is less than 365 days ago.)
			if [ "$PrvStatus" = "UP" ] ; then
				if [ "$PrvDateInSec" -lt "$YearBeforeReal" ] ; then
					# The previous date was more than a week ago
					let YearlyUpTime=$CurDateInSec-$YearBeforeReal
				else
					# The previous date was less than a week ago
					let YearlyUpTime=$YearlyUpTime+$ElapsedTime
				fi
			else
				# Assert PrvStatus = DOWN
				if [ "$PrvDateInSec" -lt "$YearBeforeReal" ] ; then
					# The previous date was more than a week ago
					let YearlyDownTime=$CurDateInSec-$YearBeforeReal
				else
					# The previous date was less than a week ago
					let YearlyDownTime=$YearlyDownTime+$ElapsedTime
				fi
			fi
		fi
	fi

	echo -e "\t\t\t<tr>" >> $TmpHTML
	if [ "$PrvStatus" = "UP" ] ; then
		let TotalUpTime=$TotalUpTime+$ElapsedTime
		echo -e "\t\t\t\t<td align="$quote"centre"$quote" td style="$quote"background-color:#00FF00"$quote">" >> $TmpHTML
		echo -e "\t\t\t\t\tUp" >> $TmpHTML
		echo -e "\t\t\t\t</td>" >> $TmpHTML
		echo -e "\t\t\t\t<td align="$quote"centre"$quote" td style="$quote"background-color:#00FF00"$quote">" >> $TmpHTML
		echo -e "\t\t\t\t\t"$PrvDate"" >> $TmpHTML
		echo -e "\t\t\t\t</td>" >> $TmpHTML
		echo -e "\t\t\t\t<td align="$quote"centre"$quote" td style="$quote"background-color:#00FF00"$quote">" >> $TmpHTML
		echo -e "\t\t\t\t\t$CurDate" >> $TmpHTML
		echo -e "\t\t\t\t</td>" >> $TmpHTML
	else
		# ASSERT PrvStatus = DOWN
		let TotalDownTime=$TotalDownTime+$ElapsedTime
		echo -e "\t\t\t\t<td align="$quote"centre"$quote" td style="$quote"background-color:#FF0000"$quote">" >> $TmpHTML
		echo -e "\t\t\t\t\tDown" >> $TmpHTML
		echo -e "\t\t\t\t</td>" >> $TmpHTML
		echo -e "\t\t\t\t<td align="$quote"centre"$quote" td style="$quote"background-color:#FF0000"$quote">" >> $TmpHTML
		echo -e "\t\t\t\t\t"$PrvDate"" >> $TmpHTML
		echo -e "\t\t\t\t</td>" >> $TmpHTML
		echo -e "\t\t\t\t<td align="$quote"centre"$quote" td style="$quote"background-color:#FF0000"$quote">" >> $TmpHTML
		echo -e "\t\t\t\t\t$CurDate" >> $TmpHTML
		echo -e "\t\t\t\t</td>" >> $TmpHTML
	fi
	echo -e "\t\t\t</tr>" >> $TmpHTML
	PrvStatus=$CurStatus
	PrvDate=$CurDate
	PrvDateInSec=$CurDateInSec
	((index += 1))
done

CurDateInSec=$RealTime
CurDate=`date`
if (( FileLen == 1 )) ; then
	# ASSERT loop never executed, system has only been in one state.
	CurStatus=$PrvStatus
fi
let ElapsedTime=$CurDateInSec-$PrvDateInSec

# Need to do a final weekly up/down calculation.
# What if there is not 7 days of history?
if [ "$WeeklyDownTime" != 0 ] || [ "$WeeklyUpTime" != 0 ] || [ "$PrvDateInSec" -lt "$WeekBeforeReal" ] ; then
	# Assert the logs go back at least one week. (We already know the CurDate is less than 7 days ago, it's today!)
	if [ "$PrvStatus" = "UP" ] ; then
		if [ "$PrvDateInSec" -lt "$WeekBeforeReal" ] ; then
			# The previous date was more than a week ago
			let WeeklyUpTime=$CurDateInSec-$WeekBeforeReal
		else
			# The previous date was less than a week ago
			let WeeklyUpTime=$WeeklyUpTime+$ElapsedTime
		fi
	else
		# Assert PrvStatus = DOWN
		if [ "$PrvDateInSec" -lt "$WeekBeforeReal" ] ; then
			# The previous date was more than a week ago
			let WeeklyDownTime=$CurDateInSec-$WeekBeforeReal
		else
			# The previous date was less than a week ago
			let WeeklyDownTime=$WeeklyDownTime+$ElapsedTime
		fi
	fi
fi
# Need to do a final monthly up/down calculation.
# What if there is not 30 days of history?
if [ "$MonthlyDownTime" != 0 ] || [ "$MonthlyUpTime" != 0 ] || [ "$PrvDateInSec" -lt "$MonthBeforeReal" ] ; then
	# Assert the logs go back at least one month. (We already know the CurDate is less than 30 days ago, it's today!)
	if [ "$PrvStatus" = "UP" ] ; then
		if [ "$PrvDateInSec" -lt "$MonthBeforeReal" ] ; then
			# The previous date was more than a month ago
			let MonthlyUpTime=$CurDateInSec-$MonthBeforeReal
		else
			# The previous date was less than a month ago
			let MonthlyUpTime=$MonthlyUpTime+$ElapsedTime
		fi
	else
		# Assert PrvStatus = DOWN
		if [ "$PrvDateInSec" -lt "$MonthBeforeReal" ] ; then
			# The previous date was more than a month ago
			let MonthlyDownTime=$CurDateInSec-$MonthBeforeReal
		else
			# The previous date was less than a month ago
			let MonthlyDownTime=$MonthlyDownTime+$ElapsedTime
		fi
	fi
fi
# Need to do a final yearly up/down calculation.
# What if there is not 365 days of history?
if [ "$YearlyDownTime" != 0 ] || [ "$YearlyUpTime" != 0 ] || [ "$PrvDateInSec" -lt "$YearBeforeReal" ] ; then
	# Assert the logs go back at least one year. (We already know the CurDate is less than 365 days ago, it's today!)
	if [ "$PrvStatus" = "UP" ] ; then
		if [ "$PrvDateInSec" -lt "$YearBeforeReal" ] ; then
			# The previous date was more than a year ago
			let YearlyUpTime=$CurDateInSec-$YearBeforeReal
		else
			# The previous date was less than a year ago
			let YearlyUpTime=$YearlyUpTime+$ElapsedTime
		fi
	else
		# Assert PrvStatus = DOWN
		if [ "$PrvDateInSec" -lt "$YearBeforeReal" ] ; then
			# The previous date was more than a year ago
			let YearlyDownTime=$CurDateInSec-$YearBeforeReal
		else
			# The previous date was less than a year ago
			let YearlyDownTime=$YearlyDownTime+$ElapsedTime
		fi
	fi
fi

echo -e "\t\t\t<tr>" >> $TmpHTML
if [ "$PrvStatus" = "UP" ] ; then
	let TotalUpTime=$TotalUpTime+$ElapsedTime
	echo -e "\t\t\t\t<td align="$quote"centre"$quote" td style="$quote"background-color:#00FF00"$quote">" >> $TmpHTML
	echo -e "\t\t\t\t\tUp" >> $TmpHTML
	echo -e "\t\t\t\t</td>" >> $TmpHTML
	echo -e "\t\t\t\t<td align="$quote"centre"$quote" td style="$quote"background-color:#00FF00"$quote">" >> $TmpHTML
	echo -e "\t\t\t\t\t"$PrvDate"" >> $TmpHTML
	echo -e "\t\t\t\t</td>" >> $TmpHTML
	echo -e "\t\t\t\t<td align="$quote"centre"$quote" td style="$quote"background-color:#00FF00"$quote">" >> $TmpHTML
	echo -e "\t\t\t\t\t$CurDate" >> $TmpHTML
	echo -e "\t\t\t\t</td>" >> $TmpHTML
else
	# ASSERT PrvStatus = DOWN
	let TotalDownTime=$TotalDownTime+$ElapsedTime
	echo -e "\t\t\t\t<td align="$quote"centre"$quote" td style="$quote"background-color:#FF0000"$quote">" >> $TmpHTML
	echo -e "\t\t\t\t\tDown" >> $TmpHTML
	echo -e "\t\t\t\t</td>" >> $TmpHTML
	echo -e "\t\t\t\t<td align="$quote"centre"$quote" td style="$quote"background-color:#FF0000"$quote">" >> $TmpHTML
	echo -e "\t\t\t\t\t"$PrvDate"" >> $TmpHTML
	echo -e "\t\t\t\t</td>" >> $TmpHTML
	echo -e "\t\t\t\t<td align="$quote"centre"$quote" td style="$quote"background-color:#FF0000"$quote">" >> $TmpHTML
	echo -e "\t\t\t\t\t$CurDate" >> $TmpHTML
	echo -e "\t\t\t\t</td>" >> $TmpHTML
fi
echo -e "\t\t\t</tr>" >> $TmpHTML

let TotalTime=$CurDateInSec-$InitialDateInSec

UpTimeFraction=`bc <<< "scale = 6; ($TotalUpTime / $TotalTime)"`
UpTimePercent=`bc <<< "$UpTimeFraction * 100"`
UpTimeDisplay=`printf "%.4f\n" $UpTimePercent`

DownTimeFraction=`bc <<< "scale = 6; ($TotalDownTime / $TotalTime)"`
DownTimePercent=`bc <<< "$DownTimeFraction * 100"`
DownTimeDisplay=`printf "%.4f\n" $DownTimePercent`

WeekUpTimeFraction=`bc <<< "scale = 6; ($WeeklyUpTime / $SecondsPerWeek)"`
WeekUpTimePercent=`bc <<< "$WeekUpTimeFraction * 100"`
WeeklyUpTimeDisplay=`printf "%.4f\n" $WeekUpTimePercent`

WeeklyDownTimeFraction=`bc <<< "scale = 6; ($WeeklyDownTime / $SecondsPerWeek)"`
WeeklyDownTimePercent=`bc <<< "$WeeklyDownTimeFraction * 100"`
WeeklyDownTimeDisplay=`printf "%.4f\n" $WeeklyDownTimePercent`

MonthlyUpTimeFraction=`bc <<< "scale = 6; ($MonthlyUpTime / $SecondsPerMonth)"`
MonthlyUpTimePercent=`bc <<< "$MonthlyUpTimeFraction * 100"`
MonthlyUpTimeDisplay=`printf "%.4f\n" $MonthlyUpTimePercent`

MonthlyDownTimeFraction=`bc <<< "scale = 6; ($MonthlyDownTime / $SecondsPerMonth)"`
MonthlyDownTimePercent=`bc <<< "$MonthlyDownTimeFraction * 100"`
MonthlyDownTimeDisplay=`printf "%.4f\n" $MonthlyDownTimePercent`

YearlyUpTimeFraction=`bc <<< "scale = 6; ($YearlyUpTime / $SecondsPerYear)"`
YearlyUpTimePercent=`bc <<< "$YearlyUpTimeFraction * 100"`
YearlyUpTimeDisplay=`printf "%.4f\n" $YearlyUpTimePercent`

YearlyDownTimeFraction=`bc <<< "scale = 6; ($YearlyDownTime / $SecondsPerYear)"`
YearlyDownTimePercent=`bc <<< "$YearlyDownTimeFraction * 100"`
YearlyDownTimeDisplay=`printf "%.4f\n" $YearlyDownTimePercent`

((UpSec=TotalUpTime%60, TotalUpTime/=60, UpMin=TotalUpTime%60, TotalUpTime/=60, UpHrs=TotalUpTime%24, UpDays=TotalUpTime/24))
TotalUpTime=`printf "%d:%02d:%02d:%02d" $UpDays $UpHrs $UpMin $UpSec`

((DownSec=TotalDownTime%60, TotalDownTime/=60, DownMin=TotalDownTime%60, TotalDownTime/=60, DownHrs=TotalDownTime%24, DownDays=TotalDownTime/24))
TotalDownTime=`printf "%d:%02d:%02d:%02d" $DownDays $DownHrs $DownMin $DownSec`

## Now that we have all our statistics we can build the full HTML file.
## First lets strip the trailing _hist from the file name
SystemID1=`echo $NoExtension | awk -F_ '{print $1}'`
SystemID=`echo $SystemID1 | awk -F/ '{print $NF}'`

echo "<HTML>" > $HTML
echo "<"$bang"-- Begin Head -->" >> $HTML
echo -e "\t<HEAD>" >> $HTML
echo -e "\t\t<TITLE>"$DatFileClass" availability statistics for "$SystemID"</TITLE>" >> $HTML
echo -e "\t</HEAD>" >> $HTML
echo "<"$bang"-- End Head Begin Body -->" >> $HTML
echo -e "\t<BODY bgcolor="$quote"#000000"$quote">" >> $HTML
echo -e "\t\t<font color="$quote"#ffffff"$quote">" >> $HTML
echo -e "\t\t<H2>For "$SystemID" we have the following "$DatFileClass" statistics:</H2>" >> $HTML
echo -e "\t\t<center>" >> $HTML
echo -e "\t\t\tTotal Up Time (DD:HH:MM:SS): "$TotalUpTime" Percent Up Time: "$UpTimeDisplay"%<br>" >> $HTML
echo -e "\t\t\tTotal Down Time (DD:HH:MM:SS): "$TotalDownTime" Percent Down Time: "$DownTimeDisplay"%<br>" >> $HTML
echo -e "\t\t\tWeekly Uptime Percent: "$WeeklyUpTimeDisplay"% Weekly Downtime Percent: "$WeeklyDownTimeDisplay"%<br>" >> $HTML
echo -e "\t\t\tLast 30 days Uptime Percent: "$MonthlyUpTimeDisplay"% Last 30 days Downtime Percent: "$MonthlyDownTimeDisplay"%<br>" >> $HTML
echo -e "\t\t\tLast 365 days Uptime Percent: "$YearlyUpTimeDisplay"% Last 365 days Downtime Percent: "$YearlyDownTimeDisplay"%<br>" >> $HTML
echo -e "\t\t\tNote that percentages may not add to 100 due to rounding.<br>" >> $HTML
echo -e "\t\t\tAll zeros in the above percentages means not enough history to report on yet. (I.e. a year, month or week of history has yet to happen.)<br><br>" >> $HTML
echo -e "\t\t<hr><br>" >> $HTML
echo -e "\t\t<table width="$quote"70%"$quote">" >> $HTML
cat $TmpHTML >> $HTML
echo -e "\t\t</table>" >> $HTML
echo -e "\t\t</center>" >> $HTML
echo -e "\t</BODY>" >> $HTML
echo "</HTML>" >> $HTML

rm $TmpHTML
