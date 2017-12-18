#!/bin/sh

curl_out='curl_out.dat'
ip_port=$(netstat -ntl | awk '/:9101/{print $4;exit}')
echo $ip_port
curl -s "http://${ip_port}/diagnostic/RT/0/DumpAllKeys/REP_GROUP_KEY?useStyle=raw" -o $curl_out

awk -F: '/schemaType/{print $4}' $curl_out

