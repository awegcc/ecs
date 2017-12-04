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
        from_day=$(date +'%Y%m%d' -d"$i day ago")
done
datelist="${datelist}$(date +'.%Y%m%d*,}')"
datenow=$(date '+%Y%m%d')

echo viprexec -i -c "zgrep -h candidateCount /var/log/blobsvc-chunk-reclaim.log${datelist}"
viprexec -i -c "zgrep -h candidateCount /var/log/blobsvc-chunk-reclaim.log${datelist}" > candidateCount.log.${datenow}
echo viprexec -i -c "zgrep -h This /var/log/blobsvc-chunk-reclaim.log${datelist}"
viprexec -i -c "zgrep -h This /var/log/blobsvc-chunk-reclaim.log${datelist}" > roundEnd.log.${datenow}


for((index=0;index<128;index++))
do
    ob="OB_${index}_128_0:"
    candidateCount=$(grep ${rg}_${ob} candidateCount.log.${datenow} | grep REPO_SCAN | grep "Saving" | tail -n 1 | awk -F 'candidateCount ' '{print $2}' | awk -F ',' '{print $1}')
    failedCandidateCount=$(grep ${rg}_${ob} candidateCount.log.${datenow}  | grep REPO_SCAN | grep Saving | tail -n 1 | awk -F 'failedCandidateCount ' '{print $2}' | awk -F ',' '{print $1}')
    lastTaskTime=$(grep ${rg}_${ob} candidateCount.log.${datenow} | grep REPO_SCAN | grep Saving | tail -n 1 | awk -F 'lastTaskTime ' '{print $2}' | awk -F ' |\n|\r' '{print $1}')
    lastEndtime=$(grep ${rg}_${ob}  roundEnd.log.${datenow} | grep REPO_SCAN | grep round | tail -n 1 | awk '{print substr($1,0,19)}')
    lastDuration=$(grep ${rg}_${ob} roundEnd.log.${datenow} | grep REPO_SCAN | grep round | tail -n 1 | awk '{print $17}')
    printf "%13s candidateCount %9s, failedCandidateCount %6s, lastTaskTime %13s, lastEndtime %19s, lastDuration %11s\n"\
        $ob $candidateCount $failedCandidateCount $lastTaskTime $lastEndtime $lastDuration
done > GCVerificationAnalysis.log.${datenow}.${rg}
rm roundEnd.log.${datenow}
rm candidateCount.log.${datenow}

