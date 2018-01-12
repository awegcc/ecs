#!/bin/bash
#
if [[ $# == 2 ]]
then
    rg=$1
    days=$2
elif [[ $# == 1 ]]
then
    rg=$1
else
    echo "Usage: $0 rgId days"
    exit 1
fi

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

grep "REPO_SCAN" ${dump_data} | grep 'Saving checkpoint' > candidateCount.log
grep "REPO_SCAN" ${dump_data} | grep 'This round' > roundEnd.log

for((index=0;index<128;index++))
do
    ob="OB_${index}_128_0:"
    grep "${rg}_${ob}" candidateCount.log | tail -n 1 > result.log.${index}
    grep "${rg}_${ob}" roundEnd.log | tail -n 1 >> result.log.${index}
    eval $( awk '/ChunkReferenceScanner.java/{
                    for(i=1;i<=NF;i++){
                        if($i=="candidateCount"){
                            candidateCount=$(i+1);
                        } else if($i=="failedCandidateCount"){
                            failedCandidateCount=$(i+1);
                        } else if($i=="lastTaskTime"){
                            lastTaskTime=$(i+1);
                        }
                    }
                }
                /RepoChunkReferenceScanner.java/{
                    for(i=1;i<=NF;i++){
                        if($i=="milliseconds") {
                            roundtime=substr($1,0,19);
                            duration=$(i-1);
                        }
                    }
                }
            END{
                printf "candidateCount=%d;failedCandidateCount=%d;lastTaskTime=%d\n",candidateCount,failedCandidateCount,lastTaskTime;
                printf "lastEndtime=%s;lastDuration=%s;hours=%.2f\n",roundtime,duration,duration/1000/3600;
            }' result.log.${index} )
    printf "%13s candidateCount %9s, failedCandidateCount %6s, lastTaskTime %13s, lastEndtime %19s, lastDuration %11s (%s h)\n"\
           $ob $candidateCount $failedCandidateCount $lastTaskTime $lastEndtime $lastDuration $hours
    rm -f result.log.${index}
done > GCVerificationAnalysis.log.${datenow}.${rg}
rm -f candidateCount.log
rm -f roundEnd.log
rm -f ${dump_data}

