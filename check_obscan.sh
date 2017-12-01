#! /bin/bash

datenow=$1
rg=$2

viprexec -i -c "zgrep This /var/log/blobsvc-chunk-reclaim.log.2017112* /var/log/blobsvc-chunk-reclaim.log" > roundEnd.log.${datenow}
viprexec -i -c "zgrep candidateCount /var/log/blobsvc-chunk-reclaim.log.2017112* /var/log/blobsvc-chunk-reclaim.log" > candidateCount.log.${datenow}

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

