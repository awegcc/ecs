#!/bin/bash
#
if [[ $# == 1 ]]
then
    days=$1
else
    echo "Usage: $0 days"
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
datenow=$(date '+%Y%m%d')
dump_data=dump_data.${datenow}

# [TaskScheduler-BlobService-REPO_SCAN-ScheduledExecutor-005] DEBUG  ChunkReferenceScanner.java (line 147) Saving checkpoint for scanner REPO:urn:storageos:OwnershipInfo:d3cbdbfe-7590-4b34-afd4-4a0490dbe7cc_e8c3dc6f-cac7-40f4-b0c7-de94fd0ef724_OB_98_128_0:: candidateCount 2, failedCandidateCount 0, lastTaskTime 1515577721063
# [TaskScheduler-BlobService-REPO_SCAN-ScheduledExecutor-000]  INFO  RepoChunkReferenceScanner.java (line 217) This round GC verification of scanner:REPO:urn:storageos:OwnershipInfo:d3cbdbfe-7590-4b34-afd4-4a0490dbe7cc_5af20804-aec5-4eab-8899-df8cc7aa5b45_OB_40_128_0: last: 338941 milliseconds for objectScanCount 123928

echo viprexec -c "zgrep -h \"This\\|candidateCount\" /opt/emc/caspian/fabric/agent/services/object/main/log/blobsvc-chunk-reclaim.log${datelist}"
viprexec "zgrep -h \"This\\|candidateCount\" /opt/emc/caspian/fabric/agent/services/object/main/log/blobsvc-chunk-reclaim.log${datelist}" > ${dump_data}

awk -v type=$TYPE '$2~type{
                  if($4=="ChunkReferenceScanner.java" && $7=="Saving") {
                      dtid=substr($11,index($11,"_")+1)
                      dtid=substr(dtid,1,index(dtid,":"))
                      for(i=1;i<=NF;i++){
                          if($i=="candidateCount"){
                              array[dtid][$i]=$(i+1);
                          } else if($i=="failedCandidateCount"){
                              array[dtid][$i]=$(i+1);
                          } else if($i=="lastTaskTime"){
                              array[dtid][$i]=$(i+1);
                          }
                      }
                  }
                  else if($4=="RepoChunkReferenceScanner.java" && $7=="This") {
                      dtid=substr($11,index($11,"_")+1)
                      dtid=substr(dtid,1,index(dtid,":"))
                      for(i=1;i<=NF;i++){
                          if($i=="milliseconds") {
                              array[dtid][$i]=$(i-1);
                              array[dtid]["roundtime"]=substr($1,0,19);
                          }
                      }
                  }
    }
    END{
        printf("%48s\tcandidateCount\tfailedCandidateCount\tlastTaskTime\tlastEndtime\tlastDuration (hrs)\n","dtId")
        for(k1 in array) {
            printf("%s\t%14s\t%14s\t%d\t%s\t%s\t%.2f\n",k1,\
                                                            array[k1]["candidateCount"],\
                                                            array[k1]["failedCandidateCount"],\
                                                            array[k1]["lastTaskTime"],\
                                                            array[k1]["roundtime"],\
                                                            array[k1]["milliseconds"],\
                                                            array[k1]["milliseconds"]/3600);
        }
    }' $dump_data

rm -f $dump_data
