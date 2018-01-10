#!/bin/sh
#

if [[ $# < 1 ]]
then
    eval $(netstat -ntl | awk '{if($4~":4443" && $4!~"127.0.0.1"){printf "mgmt_addr=%s\n",$4}else if($4~":9101"){printf "dt_addr=%s\n",$4}}')
else
    mgmt_addr="$1:4443"
fi

eval $(curl -i -s -L --location-trusted -k https://${mgmt_addr}/login -u emcservice:ChangeMe | awk '/X-SDS-AUTH-TOKEN:/{printf "SDS_TOKEN=\047%s\047\n",$0}')
if [ "x$SDS_TOKEN" == "x" ]
then
    echo "get token failed"
    exit
fi

# get local varray
curl -s -L --location-trusted -k -H "${SDS_TOKEN}" "https://${mgmt_addr}/vdc/data-services/varrays" | xmllint --format -

# get local vdc
curl -s -L --location-trusted -k -H "${SDS_TOKEN}" "https://${mgmt_addr}/object/vdcs/vdc/local" | xmllint --format -

# get vdc_list
curl -s -L --location-trusted -k -H "${SDS_TOKEN}" "https://${mgmt_addr}/object/vdcs/vdc/list" | xmllint --format -

