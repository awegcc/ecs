#!/bin/sh

WORK_DIR=`pwd`
MACHINES=MACHINES

repo_keywords='RepoReclaimer.*successfully.recycled.repo'
btree_keywords='ReclaimState.*Chunk.*reclaimed:true'
log_path="/opt/emc/caspian/fabric/agent/services/object/main/log/"
log_file='cm-chunk-reclaim.log*'
within_days=1
output_file=${WORK_DIR}/gc.reclaimed_history

[ ! -s $MACHINES ] && echo "error $MACHINES" && exit
rm -f ${output_file}*

xargs -a ${MACHINES} -I NODE -P0 sh -c \
           'ssh NODE "find $1 -maxdepth 1 -mtime -$2 -name \"$3\" -exec zgrep \"$4\\|$5\" {} \;" >${6}-NODE 2>/dev/null'\
           -- $log_path $within_days $log_file $repo_keywords $btree_keywords $output_file


awk -F: '/ReclaimState.java/{
            count[$1]["btree"]++
         }
         /RepoReclaimer.java/{
            count[$1]["repo"]++
         } END{
            printf("%-14s %28s %28s\n","time","btreeCount( total size GB )","repoCount( total size GB )")
            n=asorti(count,sorted)
            chunk_size=134217600/(1024*1024*1024)
            for(i=1;i<=n;i++){
                btree_sum += count[sorted[i]]["btree"]
                repo_sum += count[sorted[i]]["repo"]
                printf("%-14s %12d(%12.2f ) %12d(%12.2f )\n",\
                       sorted[i],count[sorted[i]]["btree"],count[sorted[i]]["btree"]*chunk_size,\
                       count[sorted[i]]["repo"],count[sorted[i]]["repo"]*chunk_size)
            }
            printf("%-14s %12d(%12.2f ) %12d(%12.2f )\n","summary",btree_sum,btree_sum*chunk_size,repo_sum,repo_sum*chunk_size)
         }' ${output_file}-*

