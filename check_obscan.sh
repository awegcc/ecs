#!/bin/bash
#
#

print_usage()
{
    echo "Usage: $0 rgId days"
    exit 1
}


if [[ $# == 2 ]]
then
    rg=$1
    days=$2
elif [[ $# == 1 ]]
then
    rg=$1
else
    print_usage
fi

datelist='{'
for((i=1;i<=days;i++))
do
	day=$(date +',.%Y%m%d*' -d"$i day ago")
	datelist="$datelist$day"
	from_day=$(date +'%Y%m%d' -d"$i day ago")
done
datelist="${datelist}}"
datenow=$(date '+%Y%m%d')
dump_data=dump_data.${datenow}
echo "dump log from $from_day to $datenow to $dump_data"

#viprexec -i -c "zgrep This /var/log/blobsvc-chunk-reclaim.log.2017{1129,1130,1201}* /var/log/blobsvc-chunk-reclaim.log" > roundEnd.log.${datenow}
#viprexec -i -c "zgrep candidateCount /var/log/blobsvc-chunk-reclaim.log.2017{1129,1130,1201}* /var/log/blobsvc-chunk-reclaim.log" > candidateCount.log.${datenow}
echo viprexec -i -c "zgrep 'This\|candidateCount' /var/log/blobsvc-chunk-reclaim.log${datelist} /var/log/blobsvc-chunk-reclaim.log"
#viprexec -i -c "zgrep 'This\|candidateCount' /var/log/blobsvc-chunk-reclaim.log${datelist} /var/log/blobsvc-chunk-reclaim.log" > ${dump_data}

exit 0
zgrep "This" /root/dump_data.dat > roundEnd.log.${datenow}
zgrep "candidateCount" /root/dump_data.dat > candidateCount.log.${datenow}

for((i=0;i<128;i++))
do
	ob="OB_${i}_128_0:"
    candidateCount=$(grep ${rg}_OB_${i}_128_0 candidateCount.log.${datenow} | grep REPO_SCAN | grep "Saving" | tail -n 1 | awk -F 'candidateCount ' '{print $2}' | awk -F ',' '{print $1}')
    failedCandidateCount=$(grep ${rg}_OB_${i}_128_0 candidateCount.log.${datenow}  | grep REPO_SCAN | grep Saving | tail -n 1 | awk -F 'failedCandidateCount ' '{print $2}' | awk -F ',' '{print $1}')
    lastTaskTime=$(grep ${rg}_OB_${i}_128_0 candidateCount.log.${datenow}  | grep REPO_SCAN | grep Saving | tail -n 1 | awk -F 'lastTaskTime ' '{print $2}' | awk -F ' |\n|\r' '{print $1}')
    lastEndtime=$(grep ${rg}_OB_${i}_128_0 roundEnd.log.${datenow}  | grep REPO_SCAN | grep round | tail -n 1 | awk -F '2017-' '{print $2}' | awk -F ',' '{print $1}')
    lastDuration=$(grep ${rg}_OB_${i}_128_0 roundEnd.log.${datenow}  | grep REPO_SCAN | grep round | tail -n 1 | awk '{print $17}')
    #eval $( awk -v urn="${rg}_${ob}" '$2~"REPO_SCAN" && $9=="round" && $13~urn{roundtime=substr($1,index($1,":")+1,19);tv=$17}END{printf "lastEndtime=%s;lastDuration=%s\n",roundtime,tv}' roundEnd.log.${datenow} )
	printf "%13s candidateCount %9s, failedCandidateCount %6s, lastTaskTime %13s, lastEndtime %19s, lastDuration %11s\n"\
	       $ob $candidateCount $failedCandidateCount $lastTaskTime $lastEndtime $lastDuration
done > GCVerificationAnalysis.log.${datenow}.${rg}
#rm roundEnd.log.${datenow}
#rm candidateCount.log.${datenow}
#rm ${dump_data}

