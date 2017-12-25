#!/bin/sh
# get rep_group id
declare -a rgids

if [[ $# < 1 ]]
then
    ip_port=$(netstat -ntl | awk '/:9101/{print $4;exit}')
else
    ip_port="$1:9101"
fi

eval $(curl -s "http://${ip_port}/diagnostic/RT/0/DumpAllKeys/REP_GROUP_KEY?useStyle=raw" | awk 'BEGIN{i=0}/schemaType/{printf "rgids[%d]=%s\n",i++,$4}')

for rgid in ${rgids[@]}
do
    echo "rgid: $rgid"
done

