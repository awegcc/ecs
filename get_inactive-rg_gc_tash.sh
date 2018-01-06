#!/bin/sh
#
# get RG's gc tasks
#
declare -a rg_list
TYPE='BTREE'
ip_port=''

function print_usage()
{
    echo "$0 -h ip -t [btree|repo]"
    exit
}

while getopts ':t:h:v' opt
do
    case $opt in
    h) ip_port="${OPTARG}:9101"
    ;;
    t)
        TYPE="${OPTARG^^}"
    ;;
    ?) echo 'error'
       print_usage
    ;;
    esac
done

if [ "x${ip_port}" == "x" ]
then
    ip_port=$(netstat -ntl | awk '/:9101/{print $4;exit}')
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

eval $(curl -s "http://${ip_port}/ownership/listInactiveRg" | awk -F: '{for(i=1;i<=NF;i++) if($i=="ReplicationGroupInfo")printf("rg_list[%d]=%s\n",n++,$(i+1))}')
if [ "x${#rg_list[@]}" == 'x0' ]
then
    echo "Can not get inactive rg list"
    exit
fi

dump_file="${TYPE}_GC_TASK_DUMP"
all_url_file="${TYPE}_GC_TASK_URL"

curl -s "http://${ip_port}/diagnostic/CT/1/DumpAllKeys/CHUNK_GC_SCAN_STATUS_TASK?zone=${vdc}&type=${TYPE}&time=0&useStyle=raw&showvalue=gpb" -o $dump_file
grep http $dump_file > $all_url_file
dos2unix $all_url_file
while read -u 99 url
do
    echo "$index"
    dump_tmp="${TYPE}_GC_TASK.tmp"
    :>$dump_tmp
    curl -s "$url" -o $dump_tmp
    
    for rgid in ${rg_list[@]}
    do
        if [ "x${#rgid}" != "x36" ]
        then
            echo "invalid rg: $rgid"
            continue
        fi
        grep -B1 $rgid $dump_tmp >> "${dump_file}_${rg}"
    done
done 99<$all_url_file

