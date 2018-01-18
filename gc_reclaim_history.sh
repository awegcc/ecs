#!/bin/sh

WORK_DIR=`pwd`
MACHINES=MACHINES

function search_logs
{
    echo -e "line:${LINENO} ${FUNCNAME[0]} - Start"
    local log_file=${1}*
    local within_days=$2
    local key_words="$3"
    local output_file=$4
    local log_path="/opt/emc/caspian/fabric/agent/services/object/main/log/"
    xargs -a ${MACHINES} -I NODE -P0 sh -c 'ssh NODE "find $1 -maxdepth 1 -mtime -$2 -name \"$3\" -exec zgrep $4 {} \;" >${5}$$-NODE'\
                                            -- $log_path $within_days $log_file $key_words $output_file

    echo -e "line:${LINENO} ${FUNCNAME[0]} - END"
}

[ ! -s $MACHINES ] && echo "error $MACHINES" && exit

repo_history=${WORK_DIR}/repo_gc.reclaimed_history

search_logs cm-chunk-reclaim.log 1 "RepoReclaimer.*successfully.recycled.repo" ${repo_history}-

awk -F: '{
            count[$1]++
         } END{
            printf("\033[1;34m%s\033[0m\n", "====> Repo GC Reclaim History")
            for(i in count) {
                chunk_sum += count[i]
                printf("%s reclaimed %6d chunks(%8.2f GB), total reclaimed %5d chunks(%7.2f GB)\n",\
                       i,count[i],count[i]*134217600/(1024*1024*1024),chunk_sum,chunk_sum*134217600/(1024*1024*1024));
                print "  * Size is estimated with maximum chunk size, actual reclaimed size could be smaller"
            }
         }' ${repo_history}-*

