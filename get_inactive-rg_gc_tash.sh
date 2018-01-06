#!/bin/sh
#
# get RG's gc tasks
#
declare -a rgid=('fec41a5d-751a-41f2-8519-ee701a62dca4' '53169064-41de-438a-add1-917867e35323')
TYPE='BTREE'

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

url_link=$(curl -s "http://${ip_port}/diagnostic/RT/0/DumpAllKeys/REP_GROUP_KEY?useStyle=raw&showvalue=gpb" | grep -B1 00000000-0000-0000-0000-000000 | grep http)

eval $(curl -s "${url_link%$'\r'}" | awk -F'"' -v varray=$cos '{if($1~"key:"&&$2~"VirtualDataCenterData"){value=substr($2,index($2,"-u")+1)}else if($2~varray){vdc=value;exit}}END{printf("vdc=%s\n",vdc)}')
if [ "x${vdc}" == "x" ]
then
    echo "can not get vdc of ${ip_port}"
    exit
fi

echo $vdc
echo $cos


dump_file="TASK_${TYPE}_GC_DUMP"
all_url_file="ALL_${TYPE}_GC_URL"

curl -s "http://${ip_port}/diagnostic/CT/1/DumpAllKeys/CHUNK_GC_SCAN_STATUS_TASK?zone=${vdc}&type=${TYPE}&time=0&useStyle=raw&showvalue=gpb" -o $dump_file
grep http $dump_file > $all_url_file
dos2unix $all_url_file
while read -u 99 url
do
    index=$(echo $url | awk -F_ '{print $4}')
    echo "process $index"
    dump_tmp="All_${TYPE}_TASK_OF_${index}_128"
    curl -s "$url" -o $dump_tmp
    
    for rg in ${rgid[@]}
    do
        grep -B1 $rg $dump_tmp >> "${dump_file}_${rg}"
    done

done 99<$all_url_file

