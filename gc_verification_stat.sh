#!/bin/bash
#
if [[ $# == 1 ]]
then
    days=$1
elif [[ $# == 0 ]]
then
    days=1
else
    echo "Usage: $0 backward_days"
    exit 1
fi

TYPE='REPO_SCAN'

datenow=$(date '+%Y%m%d-%H%M')
dump_data=${TYPE}_dump_data.$datenow
result_file=${TYPE}_GC_Verification.${datenow}

ip_port=$(netstat -ntl | awk '/:9101/{print $4;exit}')
MACHINES=".${ip_port%:*}.ip"
if [ ! -s $MACHINES ]
then
    curl -s "http://${ip_port}/diagnostic/RT/0/" | xmllint --format - | awk -F'[<>]' '/owner_ipaddress/{ip[$3]++}END{for(k in ip)print k}' > $MACHINES
fi

echo viprexec -c "zgrep -h \"This\\|candidateCount\" /opt/emc/caspian/fabric/agent/services/object/main/log/blobsvc-chunk-reclaim.log${datelist}"
#viprexec "zgrep -h \"This\\|candidateCount\" /opt/emc/caspian/fabric/agent/services/object/main/log/blobsvc-chunk-reclaim.log${datelist}" > ${dump_data}
viprexec "zgrep -h REPO_SCAN.*ChunkReferenceScanner.java /opt/emc/caspian/fabric/agent/services/object/main/log/blobsvc-chunk-reclaim.log${datelist}" > ${dump_data}
log_path='/opt/emc/caspian/fabric/agent/services/object/main/log/'
log_file='blobsvc-chunk-reclaim.log*'
repo_keywords=''
btree_keywords=''
output_file=''

xargs -a ${MACHINES} -I NODE -P0 sh -c \
           'ssh NODE "find $1 -maxdepth 1 -mtime -$2 -name \"$3\" -exec zgrep \"$4\\|$5\" {} \;" >${6}-NODE 2>/dev/null'\
           -- $log_path $days "$log_file" "$repo_keywords" "$btree_keywords" "$output_file"

awk -v type=$TYPE '$2~type{
                  if($4=="ChunkReferenceScanner.java" && $7=="Saving") {
                      for(i=1;i<=NF;i++){
                          if($i~":OwnershipInfo:") {
                              dtid=substr($i,index($i,"_")+1)
                              dtid=substr(dtid,1,index(dtid,":")-7)
                          } else if($i=="candidateCount"){
                              array[dtid][$i]=$(i+1);
                          } else if($i=="failedCandidateCount"){
                              array[dtid][$i]=$(i+1);
                          } else if($i=="lastTaskTime"){
                              array[dtid][$i]=$(i+1);
                          }
                      }
                  }
                  else if($4=="RepoChunkReferenceScanner.java" && ($7=="This" || $8=="This")) {
                      for(i=1;i<=NF;i++){
                          if($i~":OwnershipInfo:") {
                              dtid=substr($i,index($i,"_")+1)
                              dtid=substr(dtid,1,index(dtid,":")-7)
                          } else if($i=="milliseconds") {
                              array[dtid][$i]=$(i-1);
                          } else if($i=="objectScanCount:") {
                              array[dtid][$i]=$(i+1);
                          }
                      }
                      array[dtid]["lastEndtime"]=substr($1,index($1,"T")-5,14)
                  }
    }
    END{
        printf("%43s objectScanCount candidateCount failedCandidate lastTaskTime %14s lastDuration (hrs)\n","dtId","lastEndtime")
        n=asorti(array,sorted)
        for(i=1; i<=n; i++) {
            printf("%-43s %15s %14d %14s %13s %14s %12s %.2f\n",sorted[i],\
                                                            array[sorted[i]]["objectScanCount:"],\
                                                            array[sorted[i]]["candidateCount"],\
                                                            array[sorted[i]]["failedCandidateCount"],\
                                                            array[sorted[i]]["lastTaskTime"],\
                                                            array[sorted[i]]["lastEndtime"],\
                                                            array[sorted[i]]["milliseconds"],\
                                                            array[sorted[i]]["milliseconds"]/3600000);
            if(substr(sorted[i],1,index(sorted[i],"_")) != substr(sorted[i+1],1,index(sorted[i+1],"_"))) print "";
        }
    }' $dump_data | tee $result_file

rm -f $dump_data
echo "Result saved in $result_file"
