#!/bin/bash
#
if [[ $# == 1 ]]
then
    days=$1
elif [[ $# == 0 ]]
then
    days=0
else
    echo "Usage: $0 back_forward_days"
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
dump_data=dump_data.$(date '+%Y%m%d')

echo viprexec -c "zgrep -h \"This\\|candidateCount\" /opt/emc/caspian/fabric/agent/services/object/main/log/blobsvc-chunk-reclaim.log${datelist}"
viprexec "zgrep -h \"This\\|candidateCount\" /opt/emc/caspian/fabric/agent/services/object/main/log/blobsvc-chunk-reclaim.log${datelist}" > ${dump_data}

awk -v type=$TYPE '$2~type{
                  if($4=="ChunkReferenceScanner.java" && $7=="Saving") {
                      for(i=1;i<=NF;i++){
                          if($i~":OwnershipInfo:") {
                              dtid=substr($i,index($i,"_")+1)
                              dtid=substr(dtid,1,index(dtid,":")-1)
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
                              dtid=substr(dtid,1,index(dtid,":")-1)
                          } else if($i=="milliseconds") {
                              array[dtid][$i]=$(i-1);
                          }
                      }
                      array[dtid]["lastEndtime"]=substr($1,index($1,"T")-5)
                  }
    }
    END{
        printf("%50s\tcandidateCount\tfailedCandidateCount\tlastTaskTime\t%19s\tlastDuration (hrs)\n","dtId","lastEndtime")
        for(k1 in array) {
            printf("%50s\t%15s\t%21s\t%13s\t%19s\t%13s\t%.2f\n",k1,\
                                                            array[k1]["candidateCount"],\
                                                            array[k1]["failedCandidateCount"],\
                                                            array[k1]["lastTaskTime"],\
                                                            array[k1]["lastEndtime"],\
                                                            array[k1]["milliseconds"],\
                                                            array[k1]["milliseconds"]/3600000);
        }
    }' $dump_data

rm -f $dump_data
