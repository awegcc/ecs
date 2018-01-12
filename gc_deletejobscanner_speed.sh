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

exit
echo viprexec -c "zgrep -h 'DeleteJobScanner.processCleanupJob' /opt/emc/caspian/fabric/agent/services/object/main/log/blobsvc-perf-counter.log${datelist}"
viprexec "zgrep -h 'DeleteJobScanner.processCleanupJob' /opt/emc/caspian/fabric/agent/services/object/main/log/blobsvc-perf-counter.log${datelist}" > ${dump_data} 

awk '/local/{local+=$7} /remote/{remote+=$7} END{printf "local: %s, remote: %s\n",local,remote}' ${dump_data}
rm -f ${dump_data}

