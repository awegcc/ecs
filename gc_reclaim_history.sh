#!/bin/sh

WORK_DIR="`pwd`/reclaim"

repo_keywords='RepoReclaimer.*successfully.recycled.repo'
btree_keywords='ReclaimState.*Chunk.*reclaimed:true'
log_path='/opt/emc/caspian/fabric/agent/services/object/main/log/'
log_file='cm-chunk-reclaim.log*'
within_days=1
output_file=${WORK_DIR}/gc.reclaimed_history

[ ! -d $WORK_DIR ] && mkdir $WORK_DIR

if [[ $# < 1 ]]
then
    ip_port=$(netstat -ntl | awk '/:9101/{print $4;exit}')
else
    ip_port="$1:9101"
fi
MACHINES=".${ip_port%:*}.ip"
if [ ! -s $MACHINES ]
then
    curl -s "http://${ip_port}/diagnostic/RT/0/" | xmllint --format - | awk -F'[<>]' '/owner_ipaddress/{ip[$3]++}END{for(k in ip)print k}' > $MACHINES
fi

rm -f ${output_file}*
echo "Collecting past 24 hours reclaimed chunks."

xargs -a ${MACHINES} -I NODE -P0 sh -c \
           'ssh NODE "find $1 -maxdepth 1 -mtime -$2 -name \"$3\" -exec zgrep \"$4\\|$5\" {} \;" >${6}-NODE 2>/dev/null'\
           -- $log_path $within_days "$log_file" "$repo_keywords" "$btree_keywords" "$output_file"


awk -F: '/ReclaimState.java/{
            count[$1]["btree"]++
         }
         /RepoReclaimer.java/{
            count[$1]["repo"]++
         } END{
            printf("%-15s %26s %27s\n","date-time","btreeChunks(total size GB)","repoChunks(total size GB)")
            n=asorti(count,sorted)
            chunk_size=134217600/(1024*1024*1024)
            for(i=1;i<=n;i++){
                btree_sum += count[sorted[i]]["btree"]
                repo_sum += count[sorted[i]]["repo"]
                printf("%-14s %12d(%12.2f ) %12d(%12.2f )\n",\
                       sorted[i],count[sorted[i]]["btree"],count[sorted[i]]["btree"]*chunk_size,\
                       count[sorted[i]]["repo"],count[sorted[i]]["repo"]*chunk_size)
            }
            printf("%-14s %12d(%12.2f ) %12d(%12.2f )\n","total",btree_sum,btree_sum*chunk_size,repo_sum,repo_sum*chunk_size)
         }' ${output_file}-*

