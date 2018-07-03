#! /bin/sh
#############################################################################
# GenMRTGHTML.sh written by Michael Cole 2014/04/08 for Logiq3
# ---------------------------------------------------------------------------
# Purpose:
# This script will generate a html file, power.html, page with links to
# the MRTG graph for all items in the CSV file.
# ---------------------------------------------------------------------------
# Arguements:
# $0 = This script file name
# $1 = Path and file name of CSV file, i.e. /foo/bar/name.csv
# $2 = System name
# ---------------------------------------------------------------------------

if [ $# != 2 ] ; then
  echo "Usage: $0 <CSV file> <System Name>"
  exit
fi

CSVfile=$1					# Read CSVFile to meaningful variable
SystemName=$2					# Read system name to meaningful variable
MRTGHome=/home/mrtg				# Home directory of MRTG
quote=$'\042'					# This way can embed quotes in an echo, i.e. echo $quote abc $quote, returns " abc "
bang=$'\041'					# As with quotes above, enables us to embed an exclamation, !


HTML=$MRTGHome/mrtg/$SystemName/power.html

# First we build the HTML header
echo "<html>" > $HTML
echo "<"$bang"-- Begin Head -->" >> $HTML
echo -e "\t<head>" >> $HTML
echo -e "\t\t<title>$SystemName resource usage</title>" >> $HTML
echo -e "\t\t<meta http-equiv="$quote"refresh"$quote" content="$quote"120"$quote" />" >> $HTML
echo -e "\t</head>" >> $HTML
echo "<"$bang"-- End Head Begin Body -->" >> $HTML
echo -e "\t<body bgcolor="$quote"#000000"$quote">" >> $HTML
echo -e "\t\t<font color="$quote"#ffffff"$quote">" >> $HTML
echo -e "\t\t<center>" >> $HTML

LineCount=`wc -l $CSVfile | awk '{print $1}'`
index=1
while (( index <= LineCount ))
do
  line=`head -n $index $CSVfile | tail -n 1`
  URL=`echo $line | awk -F, '{print $1}'`
  PNG=`echo $line | awk -F, '{print $2}'`
  Type=`echo $line | awk -F, '{print $3}'`
  IP=`echo $line | awk -F_ '{print $1}'`
  echo "" >> $HTML
  echo -e "\t\t$Type on $SystemName ($IP)" >> $HTML
  echo -e "\t\t<br>" >> $HTML
  echo -e "\t\t<A HREF="$quote"$URL"$quote"><img src="$quote"$PNG"$quote"></A>" >> $HTML
  echo -e "\t\t<hr>" >> $HTML
  (( index += 1 ))
done

echo -e "\t\t`date`" >> $HTML
echo "" >> $HTML
echo -e "\t\t</center>" >> $HTML
echo -e "\t\t</font color>" >> $HTML
echo -e "\t</body>" >> $HTML
echo "</html>" >> $HTML
