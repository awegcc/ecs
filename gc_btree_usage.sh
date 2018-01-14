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
              aggr[$4,"garbage"]+=134217600-$3;
              aggr[$4,"count"]+=1;
              if($3<6710880) {
                  aggr[$4,"partialGarbage"]+=134217600-$3;
                  aggr[$4,"partialCount"]+=1;
              }
         }
         END{
             for(key in aggr) {
                 split(key,rg_v,SUBSEP);
                 if (rg_v[1] in rgs == 0) {
                     rgs[rg_v[1]]=1;
                     printf("%s\n", rg_v[1]);
                     printf("garbage       : %s\n", aggr[rg_v[1],"garbage"]);
                     printf("count         : %s\n", aggr[rg_v[1],"count"]);
                     printf("partialGarbage: %s\n", aggr[rg_v[1],"partialGarbage"]);
                     printf("partialCount  : %s\n", aggr[rg_v[1],"partialCount"]);
                 }
             }
         }' ${dump_file}

rm -f ${dump_file}

