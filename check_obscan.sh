#!/bin/bash
#
#

print_usage()
{
    echo "Usage: $0 rgId [date]"
    exit 1
}


if [[ $# == 2 ]]
then
    rg=$1
    datenow=$2
elif [[ $# == 1 ]]
then
    rg=$1
    datenow=$(date '+%Y%m%d')
else
    print_usage
fi

dump_data=dump_data.${datenow}

#viprexec -i -c "zgrep This /var/log/blobsvc-chunk-reclaim.log.2017{1129,1130,1201}* /var/log/blobsvc-chunk-reclaim.log" > roundEnd.log.${datenow}
#viprexec -i -c "zgrep candidateCount /var/log/blobsvc-chunk-reclaim.log.2017{1129,1130,1201}* /var/log/blobsvc-chunk-reclaim.log" > candidateCount.log.${datenow}
viprexec -i -c 'zgrep "This\|candidateCount" /var/log/blobsvc-chunk-reclaim.log.2017{1129,1130,1201}* /var/log/blobsvc-chunk-reclaim.log' > ${dump_data}

for((i=0;i<128;i++))
do
    candidateCount=$(grep ${rg}_OB_${i}_128_0 candidateCount.log.${datenow} | grep REPO_SCAN | grep "Saving" | tail -n 1 | awk -F 'candidateCount ' '{print $2}' | awk -F ',' '{print $1}')
    failedCandidateCount=$(grep ${rg}_OB_${i}_128_0 candidateCount.log.${datenow}  | grep REPO_SCAN | grep Saving | tail -n 1 | awk -F 'failedCandidateCount ' '{print $2}' | awk -F ',' '{print $1}')
    lastTaskTime=$(grep ${rg}_OB_${i}_128_0 candidateCount.log.${datenow}  | grep REPO_SCAN | grep Saving | tail -n 1 | awk -F 'lastTaskTime ' '{print $2}' | awk -F ' |\n|\r' '{print $1}')
    lastRoundTime=$(grep ${rg}_OB_${i}_128_0 roundEnd.log.${datenow}  | grep REPO_SCAN | grep round | tail -n 1 | awk -F '2017-' '{print $2}' | awk -F ',' '{print $1}')
    lastDuration=$(grep ${rg}_OB_${i}_128_0 roundEnd.log.${datenow}  | grep REPO_SCAN | grep round | tail -n 1 | awk -F 'last: ' '{print $2}' | awk -F ' milliseconds' '{print $1}')
    echo "OB_${i}_128_0: candidateCount ${candidateCount}, failedCandidateCount ${failedCandidateCount}, lastTaskTime ${lastTaskTime}, lastEndTime ${lastRoundTime}, lastDuration ${lastDuration}"
done > GCVerificationAnalysis.log.${datenow}.${rg}
#rm roundEnd.log.${datenow}
#rm candidateCount.log.${datenow}
#rm ${dump_data}

