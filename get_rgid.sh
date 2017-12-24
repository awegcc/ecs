#!/bin/sh
# get rep_group

if [[ $# < 1 ]]
then
    ip_port=$(netstat -ntl | awk '/:9101/{print $4;exit}')
else
    ip_port="$1:9101"
fi

curl -s "http://${ip_port}/diagnostic/RT/0/DumpAllKeys/REP_GROUP_KEY?useStyle=raw" | awk -F: '/schemaType/{print $4}'

