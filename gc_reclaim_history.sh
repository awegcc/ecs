#!/bin/sh

WORK_DIR=`pwd`
MACHINES=MACHINES

log_file='cm-chunk-reclaim.log'
key_words='RepoReclaimer.*successfully.recycled.repo'

function print_usage()
{
    echo "usage"
}

while getopts ':f:k:o:m:d:t:v' opt
do
    case $opt in
    f) log_file=$OPTARG
    ;;
    k) key_words=$OPTARG
    ;;
    o) out_putfile=$OPTARG
    ;;
    o) within_days=$OPTARG
    ;;
    m) MACHINES=$OPTARG
    ;;
    d) WORK_DIR=$OPTARG
    ;;
    ?) echo '  error'
       print_usage
    ;;
    esac
done


function search_logs
{
    echo -e "line:${LINENO} ${FUNCNAME[0]} - Start"
    local log_file=${1}*
    local within_days=$2
    local key_words="$3"
    local output_file=$4
    local log_path="/opt/emc/caspian/fabric/agent/services/object/main/log/"
    xargs -a ${MACHINES} -I NODE -P0 sh -c \
           'ssh NODE "find $1 -maxdepth 1 -mtime -$2 -name \"$3\" -exec zgrep $4 {} \;" >${5}-NODE 2>/dev/null'\
           -- $log_path $within_days $log_file $key_words $output_file

    echo -e "line:${LINENO} ${FUNCNAME[0]} - END"
}

[ ! -s $MACHINES ] && echo "error $MACHINES" && exit

repo_history=${WORK_DIR}/repo_gc.reclaimed_history
rm -f ${repo_history}*

search_logs cm-chunk-reclaim.log 1 "RepoReclaimer.*successfully.recycled.repo" ${repo_history}-

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
         }' ${repo_history}-*

