#!/bin/sh

WORK_DIR=`pwd`
MACHINES=MACHINE

repo_keywords='RepoReclaimer.java*successfully.recycled.repo'
btree_keywords='ReclaimState.java*Chunk.*reclaimed:true'
log_path="/opt/emc/caspian/fabric/agent/services/object/main/log/"
log_file='cm-chunk-reclaim.log*'
within_days=1
output_file=${WORK_DIR}/gc.reclaimed_history

[ ! -s $MACHINES ] && echo "error $MACHINES" && exit
rm -f ${output_file}*

xargs -a ${MACHINES} -I NODE -P0 sh -c \
           'ssh NODE "find $1 -maxdepth 1 -mtime -$2 -name \"$3\" -exec zgrep \"$4\\|$5\" {} \;" >${6}-NODE 2>/dev/null'\
           -- $log_path $within_days $log_file $repo_keywords $btree_keywords $output_file



# 2018-01-23T22:05:01,239 [TaskScheduler-ChunkManager-DEFAULT_BACKGROUND_OPERATION-ScheduledExecutor-173]  INFO  ReclaimState.java (line 45) Chunk f181057c-6fa3-4f4c-9612-3d7b438cd459 reclaimed:true
# 2017-06-30T20:06:23,163 [TaskScheduler-ChunkManager-DEFAULT_BACKGROUND_OPERATION-ScheduledExecutor-234]  INFO  RepoReclaimer.java (line 649) successfully recycled repo 3a0a0535-5d00-47d5-a293-96cfb93a0c59
awk -F: '{
            count[$1]++
         } END{
            printf("\033[1;34m%s\033[0m\n", "====> Repo GC Reclaim History")
            n=asorti(count,sorted)
            chunk_size=134217600/(1024*1024*1024)
            for(i=1;i<=n;i++){
                chunk_sum += count[sorted[i]]
                printf("%s reclaimed %6d chunks(%8.2f GB), total reclaimed %5d chunks(%7.2f GB)\n",\
                       sorted[i],count[sorted[i]],count[sorted[i]]*chunk_size,chunk_sum,chunk_sum*chunk_size);
            }
            print "  * Size is estimated with maximum chunk size, actual reclaimed size could be smaller"
         }' ${output_file}-*

