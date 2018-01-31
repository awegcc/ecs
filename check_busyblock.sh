#!/bin/sh

if [[ $# < 1 ]]
then
    ip_port=$(netstat -ntl | awk '/:9101/{print $4;exit}')
else
    ip_port="$1:9101"
fi

curl -s "http://${ip_port}/diagnostic/SS/1/DumpAllKeys/SSTABLE_KEY?type=device&useStyle=raw" | grep -B1 schemaType > SS_device
sed -i 's/\r$//' SS_device
awk -F'[ ?]' '/http/{url=$1}/schemaType/{printf("%s?device=%s&showvalue=gpb&type=PARTITION\n",url,$6)}' SS_device > SS_device_partition

printf "%-15s  %-37s  %-16s  %-9s\n" 'device' 'partition' 'Busyblock(total)' 'Busyblock(btree+journal)'
while read -u99 URL
do
    curl -s "$URL" | grep -B1 'PARTITION_REMOVED' | awk '/schemaType/{printf("%s %s\n",$6,$8)}' > partition.id
    while read -u 98 device Partition
    do
        partitionId=${Partition%$'\r'}
        url2="${URL%&*}&type=BUSY_BLOCK&partition=$partitionId"
        curl -s "$url2" -o ${partitionId}.busyblock
        block_num=$(grep -c schemaType ${partitionId}.busyblock)
        btree_journal_num=$(grep -c 'size: 134217600' ${partitionId}.busyblock)
        printf "%-15s  %-37s  %-16s  %-9s\n" $device $partitionId $block_num $btree_journal_num
    done 98< partition.id
done 99< SS_device_partition
