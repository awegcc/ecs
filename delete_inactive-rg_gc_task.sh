#!/bin/sh
#
# get RG's gc tasks
#
declare -A rg_list
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

eval $(curl -s "http://${ip_port}/ownership/listInactiveRg" | awk -F: '{for(i=1;i<=NF;i++) if($i=="ReplicationGroupInfo")printf("rg_list[%s]=0\n",$(i+1))}')
if [ "x${#rg_list[@]}" == 'x0' ]
then
    echo "Can not get inactive rg list"
    exit
fi

dump_file="${TYPE}_GC_VERIFICATION_TASK_DUMP"
all_url_file="${TYPE}_GC_VERIFICATION_TASK_URL"
#curl -s "http://${ip_port}/diagnostic/CT/1/DumpAllKeys/CHUNK_GC_SCAN_STATUS_TASK?zone=${vdc}&type=${TYPE}&time=0&useStyle=raw&showvalue=gpb" | grep 'http' > $all_url_file
all_url_file=ALL_BTREE_GC_URL
dos2unix $all_url_file
while read -u 99 url
do
    dt_ip_port=$(echo $url | awk -F/ '{print $3}')
    dtId=$(echo $url | cut -d/ -f4)
    eval $(curl -s "http://${dt_ip_port}/stats/ssm/varraycapacity/" | awk -F'[<>]' '/VarrayId/{printf "dt_cos=\047%s\047\n",$3}')
    echo "$dtId"
    dump_tmp="${TYPE}_GC_TASK.tmp"
    curl -s "$url" -o $dump_tmp
    
    for rgid in ${!rg_list[@]}
    do
        echo "rgid: $rgid"
        grep -B1 $rgid $dump_tmp | grep 'schemaType' > ${dump_file}_${rgid}
        count=$(grep -c 'schemaType' ${dump_file}_${rgid})
        rg_list[$rgid]=$((rg_list[$rgid]+count))
        while read -u 98 id_line
        do
            chunkid=$(echo $id_line | cut -d' ' -f10)
            echo "chunkid $chunkid"
            # cleanupGCVerificationTask PUT /cleanupTask/{cos}/{level}/{chunk}
            curl -X PUT -L "http://${dt_ip_port}/triggerGcVerification/cleanupTask/${dt_cos}/1/${chunkid%$'\r'}"
        done 98<${dump_file}_${rgid}
    done
done 99<$all_url_file

for rgid in ${!rg_list[@]}
do
    echo "$RG: rgid ${TYPE}_GC_TASK: ${rg_list[$rgid]}"
done
