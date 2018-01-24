#!/bin/sh
declare -A pmap

if [[ $# < 1 ]]
then
    ip_port=$(netstat -ntl | awk '/:9101/{print $4;exit}')
else
    ip_port="$1:9101"
fi

eval $(curl -s "http://${ip_port}/stats/ssm/varraycapacity/" | awk -F'[<>]' '/VarrayId/{printf "cos=\047%s\047\n",$3}')
if [ "x${cos}" == "x" ]
then
    echo "can not get cos of ${ip_port}"
    exit
fi


curl -s "http://$(hostname -i):9101/diagnostic/SS/1/DumpAllKeys/SSTABLE_KEY?type=device&useStyle=raw" | grep -B1 schemaType > SS_device
# http://10.240.29.31:9101/urn:storageos:OwnershipInfo:79634a09-0dad-44be-bee1-7a5766947a43__SS_11_128_1:/SSTABLE_KEY/?type=device
# schemaType SSTABLE_KEY type DEVICE device 10.240.29.36
dos2unix -q SS_device
awk -F'[ ?]' '/http/{url=$1}/schemaType/{printf("%s?device=%s&showvalue=gpb&type=PARTITION\n",url,$6)}' SS_device > SS_device_partition
# http://10.240.29.33:9101/urn:storageos:OwnershipInfo:79634a09-0dad-44be-bee1-7a5766947a43__SS_19_128_1:/SSTABLE_KEY/?type=PARTITION&device=10.240.29.31&showvalue=gpb
# http://10.240.29.33:9101/urn:storageos:OwnershipInfo:79634a09-0dad-44be-bee1-7a5766947a43__SS_19_128_1:/SSTABLE_KEY/?device=10.240.29.31&showvalue=gpb&type=PARTITION

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
        pmap[$partitionId]=btree_journal_num
        printf "%-15s  %-37s  %-16s  %-9s\n" $device $partitionId $block_num $btree_journal_num
        grep -B1 'size: 134217600' ${partitionId}.busyblock | awk -F\" '/chunkId:/{print $2}' > ${partitionId}.chunkid
    done 98< partition.id
done 99< SS_device_partition


for partition in ${!pmap[@]}
do
    mkdir -p $partition
    echo $partition
    while read -u 96 chunkid
    do
        if ! curl -s "http://${ip_port}/diagnostic/1/ShowChunkInfo?cos=$cos&chunkid=$chunkid" -o $partition/${chunkid}.info
        then
            curl -s "http://${ip_port}/diagnostic/2/ShowChunkInfo?cos=$cos&chunkid=$chunkid" -o $partition/${chunkid}.info
        fi
    done 96<${partition}.chunkid
done



