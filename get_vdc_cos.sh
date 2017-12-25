#!/bin/sh
# get vdc cos from ip

if [[ $# < 1 ]]
then
    ip_port=$(netstat -ntl | awk '/:9101/{print $4;exit}')
else
    ip_port="$1:9101"
fi

eval $(curl -s "http://${ip_port}/stats/ssm/varraycapacity/" | awk -F'[<>]' '/VarrayId/{printf "cos=\047%s\047\n",$3}')
if [ "x${cos}" == "x" ]
then
    echo "can not get cos of ${ip_port}"
    exit
fi

url_link=$(curl -s "http://${ip_port}/diagnostic/RT/0/DumpAllKeys/REP_GROUP_KEY?useStyle=raw&showvalue=gpb" | grep -B1 00000000-0000-0000-0000-000000 | grep http)

curl -s "${url_link%$'\r'}" | awk -F'"' -v varray=$cos '{if($1~"key:"){vdc=substr($2,10)}else if($2~varray){exit}}END{printf("%s  %s\n",vdc,varray)}'

