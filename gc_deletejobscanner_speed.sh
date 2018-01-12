#!/bin/bash
#
if [[ $# == 1 ]]
then
    days=$1
    datelist=$(date +'.%Y%m%d*' -d"$day day ago")
else
    days=0
    datelist=$(date +'.%Y%m%d*' -d"$day day ago")
fi

datelist=$(date +'.%Y%m%d*' -d"$day day ago")
datenow=$(date '+%Y%m%d')
dump_data=dump_data.${datenow}

echo $datelist

#2018-01-12T10:43:00,004 PERF 1515753780004 : DeleteJobScanner.processCleanupJob_local count 353 average 16598 us deviation 25131
#2018-01-12T10:43:00,004 PERF 1515753780004 : DeleteJobScanner.processCleanupJob_remote count 254 average 3796 us deviation 5363
#2018-01-12T10:43:10,005 PERF 1515753790005 : DeleteJobScanner.processCleanupJob_local count 516 average 20644 us deviation 41102
#2018-01-12T10:43:10,005 PERF 1515753790005 : DeleteJobScanner.processCleanupJob_remote count 96 average 9366 us deviation 37881
#2018-01-12T10:43:20,004 PERF 1515753800004 : DeleteJobScanner.processCleanupJob_local count 377 average 21780 us deviation 35603
#2018-01-12T10:43:20,004 PERF 1515753800004 : DeleteJobScanner.processCleanupJob_remote count 264 average 9020 us deviation 16936
#2018-01-12T10:43:30,003 PERF 1515753810003 : DeleteJobScanner.processCleanupJob_local count 303 average 18412 us deviation 31940

echo viprexec -c "zgrep -h 'DeleteJobScanner.processCleanupJob' /opt/emc/caspian/fabric/agent/services/object/main/log/blobsvc-perf-counter.log${datelist}"
viprexec "zgrep -h 'DeleteJobScanner.processCleanupJob' /opt/emc/caspian/fabric/agent/services/object/main/log/blobsvc-perf-counter.log${datelist}" > ${dump_data} 

awk '/local/{local+=$7} /remote/{remote+=$7} END{printf "local: %s, remote: %s\n",local,remote}' ${dump_data}
rm -f ${dump_data}

