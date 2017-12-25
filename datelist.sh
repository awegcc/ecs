#!/bin/bash

days=$1
datelist='{'
for((i=days;i>0;i--))
do
	day=$(date +'.%Y%m%d*,' -d"$i day ago")
	datelist="$datelist$day"
done

datelist="${datelist}$(date +'.%Y%m%d*}')"

echo "$datelist"
