#!/bin/sh
curl -s "http://$(hostname -i):9101/diagnostic/SS/1/DumpAllKeys/SSTABLE_KEY?type=device&useStyle=raw" | grep -B1 schemaType > SS_device
dos2unix SS_device
awk -F'[ =]' '/http/{url=$1}/schemaType/{printf("%s=PARTITION&device=%s&showvalue=gpb\n",url,$6)}' SS_device > SS_device_partition

while read URL
do
    curl -s "$URL" | grep -B1 'PARTITION_REMOVED'
done < SS_device_partition
