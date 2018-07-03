#! /bin/sh
max=255
index=222
while (( index <= max ))
do
  echo "10.0.77.$index"
  (( index += 1 ))
done
