#!/bin/bash
#
if [[ $# == 1 ]]
then
    days=$1
elif [[ $# == 0 ]]
then
    days=0
else
    echo "Usage: $0 backward_days"
    exit 1
fi

TYPE='REPO_SCAN'

datelist='{'
for((i=days;i>0;i--))
do
        day=$(date +'.%Y%m%d*,' -d"$i day ago")
        datelist="$datelist$day"
done
datelist="${datelist}$(date +'.%Y%m%d*,}')"
datenow=$(date '+%Y%m%d-%H%M')
dump_data=dump_data.$datenow
result_file=${TYPE}_GC_Verification.${datenow}

echo viprexec -c "zgrep -h \"This\\|candidateCount\" /opt/emc/caspian/fabric/agent/services/object/main/log/blobsvc-chunk-reclaim.log${datelist}"
#viprexec "zgrep -h \"This\\|candidateCount\" /opt/emc/caspian/fabric/agent/services/object/main/log/blobsvc-chunk-reclaim.log${datelist}" > ${dump_data}
viprexec "zgrep -h REPO_SCAN.*ChunkReferenceScanner.java /opt/emc/caspian/fabric/agent/services/object/main/log/blobsvc-chunk-reclaim.log${datelist}" > ${dump_data}

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
                          }
                      }
                      array[dtid]["lastEndtime"]=substr($1,index($1,"T")-5)
                  }
    }
    END{
        printf("%43s\tcandidateCount\tfailedCandidateCount\tlastTaskTime\t%19s\tlastDuration\t(hrs)\n","dtId","lastEndtime")
        n=asorti(array,sorted)
        for(i=0; i<=n; i++) {
            printf("%-43s\t%15s\t%21s\t%13s\t%19s\t%13s\t%.2f\n",sorted[i],\
                                                            array[sorted[i]]["candidateCount"],\
                                                            array[sorted[i]]["failedCandidateCount"],\
                                                            array[sorted[i]]["lastTaskTime"],\
                                                            array[sorted[i]]["lastEndtime"],\
                                                            array[sorted[i]]["milliseconds"],\
                                                            array[sorted[i]]["milliseconds"]/3600000);
        }
    }' $dump_data | tee $result_file

rm -f $dump_data
echo "Result saved in $result_file"
