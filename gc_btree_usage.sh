#!/bin/sh

LEVEL=1
dump_file="gc_btree_${LEVEL}"

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

curl "http://${ip_port}/gc/btreeUsage/${cos}/${LEVEL}" -o ${dump_file}

awk -F, '$2~"SEALED" && $3>0 {
              aggr[$4]["garbage"]+=134217600-$3;
              aggr[$4]["count"]+=1;
              if($3<6710880) {
                  aggr[$4]["partialGarbage"]+=134217600-$3;
                  aggr[$4]["partialCount"]+=1;
              }
         }
         END{
             for(k1 in aggr) {
                 printf("%s\n",k1);
                 for(k2 in aggr[k1]) {
                     printf("%-14s: %s\n",k2,aggr[k1][k2]);
                 }
             }
         }' ${dump_file}

rm -f ${dump_file}

