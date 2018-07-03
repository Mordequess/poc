#! /bin/sh
linecount=`wc -l foo.txt | awk '{print $1}'`
index=1
while (( index < linecount ))
do
  line=`head -n $index foo.txt | tail -n 1`
  If=`echo $line | awk -F/ '{print $2}'`
  Name=`echo $If | awk -F_ '{print $2}' | awk -F. '{print $1}'`
  echo -e "Here is a link to <A HREF=\"$If\">$Name</A><br>"
  (( index += 1 ))
done
