#!/bin/bash

days=$1
datelist='{'
for((i=1;i<=days;i++))
do
	day=$(date +',.%Y%m%d*' -d"$i day ago")
	datelist="$datelist$day"
done

datelist="${datelist}}"

echo "date list: $datelist"
