#!/bin/sh
# Check Missing Jrounal Region

print_usage()
{
    base_name=$(basename $0)
    echo -e "\033[0;31m Usage: \033[0m $base_name [options...]"
    echo -e " -a       (-d,-v,-i) dump, validate and inject data"
    echo -e " -t       DT name"
    echo -e " -h host  Host address"
    echo -e " -f file  Chunkid file"
    exit 1
}

#IP of Missing JR zone
ip_port=''
dt_type='LS'
rgId=(076f04fa-6856-4cb2-a07f-5debd82129d5 459c1a0d-568d-46d5-9a16-81d9701733e8 56eee2ce-5947-4fe3-bdca-aeb2d0156403)

while getopts ':h:t:' opt
do
    case $opt in
    h) ip_port="${OPTARG}:9101"
    ;;
    t) dt_type="${OPTARG}"
    ;;
    ?) echo '  error'
       print_usage
    ;;
    esac
done
if [ "x${ip_port}" == "x" ]
then
    ip_port=$(netstat -ntl | awk '/:9101/{print $4;exit}')
fi

url_addr="http://${ip_port}/stats/ssm/varraycapacity/"
eval $(curl -s $url_addr | awk -F'[<>]' '/VarrayId/{printf "cos=\047%s\047\n",$3}')
if [ "x${cos}" == "x" ]
then
    echo "can not get cos of ${ip_port}"
    exit
fi
url_addr="http://${ip_port}/diagnostic/RT/0/DumpAllKeys/REP_GROUP_KEY?useStyle=raw&showvalue=gpb"
url_link=$(curl -s $url_addr | grep -B1 00000000-0000-0000-0000-000000 | grep http)

eval $(curl -s "${url_link%$'\r'}" | awk -F'"' -v varray=$cos '{
                                                          if($1~"key:"&&$2~"VirtualDataCenterData")
                                                          {value=substr($2,index($2,"-u")+1)}
                                                          else if($2~varray)
                                                          {vdc=value;exit}
                                                        }
                                                        END{printf("zone=%s\n",vdc)}')
if [ "x${zone}" == "x" ]
then
    echo "can not get zone of $ip_port"
    exit
fi

function scan_missing_jr()
{
    if [ $# -lt 5 ] ; then
        zone=$1
        dt_type=$2
        rgId=$3
        host=$4
    fi
    dtid_file="${rgId}_${dt_type}.lst"
    url_addr="http://$ip_port/diagnostic/$dt_type/0/"
    curl -s $url_addr | xmllint --format - | awk -F'[<>]' -v rgid=$rgId '/<id>/{if($3~rgid) print $3}' > $dtid_file
    
    max_minor=$((16#7fffffffffffffff))
    while read dtId
    do
        #Dump JR to get major and minor for each entry
        url_addr="http://$ip_port/diagnostic/PR/1/DumpAllKeys/DIRECTORYTABLE_RECORD?type=JOURNAL_REGION&dtId=${dtId}&zone=${zone}&useStyle=raw"
        curl -s -L $url_addr | awk '/schemaType/{print $(NF-2),$NF}' > ${dtId}_mm.lst
        url_addr="http://$ip_port/diagnostic/PR/1/DumpAllKeys/DIRECTORYTABLE_RECORD?type=BPLUSTREE_INFO&dtId=${dtId}&zone=${zone}&useStyle=raw&showvalue=gpb"
        link=$(curl -s -L $url_addr | grep -B1 schema | grep http )
        eval $(curl -s -L ${link%$'\r'} | grep subKey | tail -n1 | awk -F'\' '/subKey:/{ printf "lastMajor=%d;lastMinor=%d\n",substr($3,4),substr($5,4)}')
        if [ "x$lastMajor" == "x" ]
        then
            echo "not find Major of $dtId"
            continue
        fi
        while read JRMajor JRMinor
        do
            echo "lastMajor:$lastMajor lastMinor:$lastMinor"
            echo "JRMajor  :$JRMajor   JRMinor  :$JRMinor"
            if (( ((16#$JRMajor)) < ((16#$lastMajor)) ))
            then
                continue
            elif (( ((16#$JRMajor)) == ((16#$lastMajor)) && ((16#$JRMinor)) < ((16#$lastMinor)) ))
            then
                continue
            elif (( ((16#$JRMajor)) == ((16#$lastMajor)) ))
            then
                if (( ((16#$JRMinor)) - ((16#$lastMinor)) == 1 && ((16#$JRMinor)) != ((16#$max_minor)) ))
                then
                    echo "JR Minor Missing:$dtId $JRMajor $JRMinor"
                    echo "dtId:$dtId zone:$zone rgId:$rgId Major:$JRMajor Minor:$JRMinor" >> MissingJR.tmp
                fi
            elif (( ((16#$JRMajor)) - ((16#$lastMajor)) == 1 ))
            then
                if (( ((16#$lastMinor)) != ((16#$max_minor)) ))
                then
                    echo "last JR Missing:$dtId $JRMajor $JRMinor"
                    echo "dtId:$dtId zone:$zone rgId:$rgId Major:$lastMajor Minor:7fffffffffffffff" >> MissingJR.tmp
                fi
                if (( ((16#$JRMinor)) != 0  && ((16#$JRMinor)) != ((16#$max_minor)) ))
                then
                    echo "JR Missing:$dtId $JRMajor $JRMinor"
                    echo "dtId:$dtId zone:$zone rgId:$rgId Major:$JRMajor Minor:0000000000000000" >> MissingJR.tmp
                fi
            else
                echo "JR Major Missing:$dtId $JRMajor $JRMinor"
                echo "from dtId:$dtId zone:$zone rgId:$rgId Major:$lastMajor Minor:$lastMinor to Major:$JRMajor Minor:$JRMinor" >> MissingJR.tmp
            fi
            lastMajor=$JRMajor
            lastMinor=$JRMinor
        done 98< ${dtId}_mm.lst
    done 99< $dtid_file
}

function fix_jr()
{
    host_not_MissingJR=10.240.29.35
    host_target=10.240.29.39
    while read MissingJR
    do
        if [[ "$(echo $MissingJR |  awk '{print $1}')"  == "from" ]]
        then
            echo "$MissingJR"
            rgId=$(echo $MissingJR | awk '{print $4}' | cut -c 6-)
            zone=$(echo $MissingJR | awk '{print $3}' | cut -c 6-)
            table=$(echo $MissingJR | awk '{print $2}' | awk -F '-' '{print $(NF)}')
            dt_type=$(echo $MissingJR | awk '{print $2}' | awk -F '_' '{print $(NF-3)}')
            targetdtId=$(echo $MissingJR | awk '{print $2}' | cut -c 6-)
            fromMajor=$(echo $MissingJR |awk '{print $(NF-4)}'|cut -c 7-)
            fromMinor=$(echo $MissingJR |awk '{print $(NF-3)}'|cut -c 7-)
            toMajor=$(echo $MissingJR |awk '{print $(NF-1)}'|cut -c 7-)
            toMinor=$(echo $MissingJR |awk '{print $NF}'|cut -c 7-)
            dtId=$(curl -s http://${host_not_MissingJR}:9101/diagnostic/$dt_type/0/ | xmllint --format - | grep id | grep $table | grep $rgId  |awk -F"<|>" '{print $3}')
            #list all the JRs in zone without JR missing
            link=$(curl -s -L "http://${host_not_MissingJR}:9101/diagnostic/PR/1/DumpAllKeys/DIRECTORYTABLE_RECORD?useStyle=raw&showvalue=gpb&type=JOURNAL_REGION&dtId=${dtId}&zone=${zone}&showvalue=gpb" | grep -B1 schema | grep http | awk -F ' |\n|\r' '{print $1}')
            echo "$fromMajor $fromMinor"
            echo "$toMajor $toMinor"
            curl -s -L ${link}| awk '/major '"$fromMajor"' minor '"$fromMinor"'/{f=1;next} /major '"$toMajor"' minor '"$toMinor"'/{f=0} f' | awk 'NR>=6' > /tmp/JRValue.${table}.tmp
        else
            rgId=$(echo $MissingJR | awk '{print $3}' | cut -c 6-)
            zone=$(echo $MissingJR | awk '{print $2}' | cut -c 6-)
            table=$(echo $MissingJR | awk '{print $1}' | awk -F '-' '{print $(NF)}')
            dt_type=$(echo $MissingJR | awk '{print $1}' | awk -F '_' '{print $(NF-3)}')
            targetdtId=$(echo $MissingJR | awk '{print $1}' | cut -c 6-)
            Major=$(echo $MissingJR |awk '{print $4}'|cut -c 7-)
            Minor=$(echo $MissingJR |awk '{print $5}'|cut -c 7-)
            dtId=$(curl -s http://${host_not_MissingJR}:9101/diagnostic/$dt_type/0/ | xmllint --format - | grep id | grep $table | grep $rgId  |awk -F"<|>" '{print $3}')
            link=$(curl -s -L "http://${host_not_MissingJR}:9101/diagnostic/PR/1/DumpAllKeys/DIRECTORYTABLE_RECORD?useStyle=raw&showvalue=gpb&type=JOURNAL_REGION&dtId=${dtId}&zone=${zone}&showvalue=gpb&major=${Major}&minor=${Minor}"| grep -B1 schema | grep http | awk -F ' |\n|\r' '{print $1}')
            curl -s -L ${link} > /tmp/JRValue.${table}.tmp
        fi
        echo "Numbers of Missing Journals:"
        grep schema JRValue.${table}.tmp | wc -l
        rgName=urn:storageos:ReplicationGroupInfo:${rgId}:global
        echo "$rgName"
        cat JRValue.${table}.tmp |tr -d $'\r'| grep -B5 secondaries | awk -F ' |"' '{if($1=="schemaType"){major=$(NF-2);minor=$NF}else if($1=="ownerInstanceId:"){ownerInstanceId=$3}else if($1=="chunkId:"){chunkId=$3}else if($1=="offset:"){offset=$2}else if($1=="endOffset:"){endoffset=$2;printf "curl -I -X PUT \"http://'"$host_target"':9101/journalinsert/'"${targetdtId}"'/%s/%s/'"$rgName"'/%s/'"${zone}"'/?instanceId=%s&startOffset=%s&endOffset=%s\"\n",major,minor,chunkId,ownerInstanceId,offset,endoffset}}' >> /tmp/fixCommand.sh
     done < /tmp/MissingJR.tmp
     rm /tmp/JRValue.*
     #execute /tmp/fixCommand.sh to fix, recommended to be checked mannully first
     #sh /tmp/fixCommand.sh
}

echo "ip   $ip_port"
echo "zone $zone"
echo "cos  $cos"
for rg in ${rgId[@]};
do
    echo "check rg: $rg"
done

