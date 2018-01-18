#!/bin/sh

WORK_DIR=`pwd`
MACHINES=MACHINES

function search_logs
{
    echo -e "line:${LINENO} ${FUNCNAME[0]} - Start"
    local log_file=$1
    local within_days=$2
    local key_words="$3"
    local output_file=$4
    local log_path="/opt/emc/caspian/fabric/agent/services/object/main/log/"
    set -x
    xargs -a ${MACHINES} -I NODE -P0 sh -c 'ssh $1 find $2 -maxdepth 1 -name ${3}* -exec zgrep -h $4 {} \; > $5-$1'  -- NODE $log_path $log_file $key_words ${output_file}
    set +x

    echo -e "line:${LINENO} ${FUNCNAME[0]} - END"
}

if [ ! -s $MACHINES ]
then
    echo "error $MACHINES"
    exit
fi

repo_history=${WORK_DIR}/repo_gc.reclaimed_history

search_logs cm-chunk-reclaim.log 1 "RepoReclaimer.*successfully.recycled.repo" ${repo_history}-
#awk -F':' '{ print $2 }' ${repo_history}-* | sed -e 's/ /T/g' | sort | uniq -c > ${repo_history}
awk -F: '{count[$1]++} END{for(i in count) printf "%d\t%s\n",count[i],i}' > ${repo_history}

if [[ ! -s ${repo_history} ]] ; then
    echo
    echo -e "line:${LINENO} ${FUNCNAME[0]} - ====> Repo GC Reclaim History"
    echo -e "line:${LINENO} ${FUNCNAME[0]} -   There's no garbage reclaimed in past 24 hrs"
fi

awk 'BEGIN{
        current_timestamp = mktime(strftime("%Y %m %d %H 00 00", systime()))
    }{
        chunk_num = $1
        time_readable = $2
        gsub(/-/," ",time_readable)
        gsub(/T/," ",time_readable)
        hr_delta = int((current_timestamp - mktime(time_readable" 00 00"))/(60*60))
        hr_chunk_map[hr_delta] = chunk_num
        hr_ts_map[hr_delta] = $2
    } END{
        print ""
        printf("\033[1;34m%s\033[0m\n", "====> Repo GC Reclaim History")
        chunk_cnt=0
        for (hr_delta in hr_chunk_map) {
            chunk_cnt += hr_chunk_map[hr_delta]
            printf("  - In past %2s hrs reclaimed %6d chunks(%8.2f GB); In %s reclaimed %5d chunks(%7.2f GB)\n", hr_delta, chunk_cnt, 134217600*chunk_cnt/(1024*1024*1024), hr_ts_map[hr_delta], hr_chunk_map[hr_delta], 134217600*hr_chunk_map[hr_delta]/(1024*1024*1024))
        }
        print "  * Size is estimated with maximum chunk size, actual reclaimed size could be smaller"
    }' ${repo_history}

