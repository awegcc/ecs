#!/bin/sh
if [[ $# < 1 ]]
then
    ip_port=$(netstat -ntl | awk '/:9101/{print $4;exit}')
else
    ip_port="$1:9101"
fi
cleanupjobs=cleanupjob.$(date +'%Y%m%d-%H%M')
suffix='DELETE_JOB_TABLE_KEY?type=CLEANUP_JOB&objectId=aa&maxkeys=1&useStyle=raw'
if [ ! -s cleanupjob_command.sh ]
then
  curl "http://${ip_port}/diagnostic/OB/0" | xmllint --format - | awk -F'[<>?]' '/table_detail_link/{print $3}' > obdt_url.list
  while read url
  do
    echo echo $url
    echo curl -s \"${url}${suffix}\"
  done < obdt_url.list > cleanupjob_command.sh
fi
sh cleanupjob_command.sh > $cleanupjobs
grep 'schemaType' $cleanupjobs | sort -k3 -n | head -4

