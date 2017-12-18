#!/bin/bash
#
# Tue Nov 28 22:51:26 CST 2017
#

PY_CRC32='crc32.py'

print_usage()
{
    base_name=$(basename $0)
    echo -e "\033[0;31m Usage: \033[0m $base_name [options...]"
    echo -e " -a       (-d,-v,-i) dump, validate and inject data"
    echo -e " -s       Dump first sealed chunk data"
    echo -e " -v       Validate dumped chunk data"
    echo -e " -i       Inject back chunk data"
    echo -e " -h host  Host address"
    echo -e " -f file  Chunkid file"
    exit 1
}

if [[ $BASH_VERSINFO < 4 ]]
then
    echo "You bash version: $BASH_VERSION"
    echo "This script need bash 4.0 or later"
    exit 0
fi

ip_port=''
dump_data='TRUE'
inject_data='FALSE'
search_mode='ACTIVE'
validate_data='FALSE'
chunkidfile='chunkid.list'

while getopts ':f:h:savi' opt
do
    case $opt in
    f) chunkidfile=$OPTARG
    ;;
    h) ip_port="${OPTARG}:9101"
    ;;
    a)
        dump_data='TRUE'
        validate_data='TRUE'
        inject_data='TRUE'
    ;;
    i)
        dump_data='FALSE'
        inject_data='TRUE'
    ;;
    s) search_mode='SEALED'
    ;;
    v)
        dump_data='FALSE'
        validate_data='TRUE'
        inject_data='FALSE'
    ;;
    ?) echo '  error'
       print_usage
    ;;
    esac
done

if [ ! -s "$chunkidfile" ]
then
    echo "$chunkidfile is invalid"
    print_usage
fi

if [ "x${ip_port}" == "x" ]
then
    ip_port=$(netstat -ntpl | awk '/:9101/{print $4}')
fi

if [ ! -s "$PY_CRC32" ]
then
    echo 'import sys'
    echo 'import zlib'
    echo 'with open(sys.argv[1], "r+b") as f:'
    echo '    offset = int(sys.argv[2])'
    echo '    data_length = int(sys.argv[3])'
    echo '    f.seek(offset)'
    echo '    print "crc32 checksum:", zlib.crc32(f.read(data_length)) & 0xffffffff'
fi > "$PY_CRC32"

eval $(curl -s "http://${ip_port}/stats/ssm/varraycapacity/" | awk -F'[<>]' '/VarrayId/{printf "cos=\047%s\047\n",$3}')
if [ "x${cos}" == "x" ]
then
    echo "can not get cos of ${ip_port}"
    print_usage
fi

# map public ip to private ip to use viprexec
declare -A ipmap=()
eval $(getrackinfo | awk 'NF==8{printf "ipmap[\"%s\"]=%s\n",$5, $1}')
#echo ${ipmap[$public_ip]}

dump_chunk_data()
{
    if [[ $# < 1 ]]
    then
        echo "dump_chunk_data need arg: chunkid"
    fi
    chunkid=$1
    echo "chunkid   : $chunkid"
    mkdir -p $chunkid
    curl -s "http://${ip_port}/diagnostic/1/ShowChunkInfo?cos=${cos}&chunkid=${chunkid}" -o $chunkid/${chunkid}.info
    # get chunk primary(zone) and sealedTime
    eval $(awk '/primary/{printf "zone=%s\n",$2};/sealedTime:/{printf "sealedTime=\047%s\047\n",$2}' $chunkid/${chunkid}.info)
    echo "zone      : $zone"
    echo "sealedTime: $sealedTime"
    # get chunk dtId
    curl -s "http://${ip_port}/diagnostic/CT/1/DumpAllKeys/CHUNK?chunkId=${chunkid}&useStyle=raw" | grep -B1 schemaType > $chunkid/${chunkid}.dtId
    eval $(awk -F/ '/http/{printf "dtId=\047%s\047\n",$4}' $chunkid/${chunkid}.dtId)
    echo "dtId      : $dtId"
    # List JR(Journal Region)
    curl -s "http://${ip_port}/diagnostic/PR/2/DumpAllKeys/DIRECTORYTABLE_RECORD?type=JOURNAL_REGION&dtId=${dtId}&zone=${zone}&useStyle=raw&showvalue=gpb"|grep -B1 schemaType > $chunkid/${chunkid}.JR
    # get JR url
    eval $(awk 'NR==1 && /http/{printf "jr_url=\047%s\047\n",$0}' $chunkid/${chunkid}.JR)
    if [ "x$jr_url" != "x" ]
    then
        echo "JR_URL    : $jr_url"
    else
        echo "JR_URL not find"
        return
    fi
    curl -s "${jr_url%$'\r'}" -o $chunkid/${chunkid}.JRDetail
    for ((timestamp=sealedTime-400000000; timestamp<=sealedTime+8000000000; timestamp+=1))
    do
        major=''
        eval $(awk -v timeval=$timestamp '$1=="schemaType"{major=$10} $1=="timestamp:"{timestamp=$2;if($2>timeval){found=1;exit}} END{if(found==1){printf "major=%s;timestamp=%s",major,timestamp}else{printf "timestamp=%s",timestamp}}' $chunkid/${chunkid}.JRDetail)
        # Dump JR content
        if [[ "x$major" != "x" ]]
        then
            startline=0
            curl -s "http://${ip_port}/journalcontent/${dtId}?zone=${zone}&major=$major" -o $chunkid/${chunkid}.JRContent.${major}
            eval $(awk -v beginpat="schemaType CHUNK chunkId $chunkid" -v sstatus="$search_mode" '$0~beginpat, $1~"isEc:"{if($1=="<value>status:" && $2==sstatus){sstat=1}else if($1=="<value>status:"){sstat=0}else if($1=="isEc:" && $2=="false" && sstat==1 ){printf "startline=%d",NR;exit}}' $chunkid/${chunkid}.JRContent.${major})
            if [[ $startline > 0 ]]
            then
                echo "major     : $major"
                echo "timestamp : $timestamp"
                for ((i=1; i<=2; i++))
                do
                    echo "startline   : $startline"
                    ssId=""
                    filename=""
                    partitionId=""
                    eval $(awk -v startline=$startline 'BEGIN{flag=1}NR>=startline{if($1~"ssId"){printf "ssId=%s;",$2}else if($1~"partitionId"){printf "partitionId=%s;",$2}else if($1~"filename"){printf "filename=%s;",$2}else if($1~"offset"&&flag){flag=0;printf "offset=%d;",$2/100}else if($1~"endOffset"){printf "endOffset=%d;startline=%s\n",$2/100,NR+3; exit}}' $chunkid/${chunkid}.JRContent.${major})

                    echo "ssId        : $ssId"
                    echo "partitionId : $partitionId"
                    echo "filename    : $filename"
                    echo viprexec -n ${ipmap[$ssId]} --dock=object-main \'"dd if=/dae/uuid-${partitionId}/${filename} of=/var/log/${chunkid}.copy${i} bs=100 skip=${offset} count=${endOffset}"\'
                    viprexec -n ${ipmap[$ssId]} --dock=object-main \'"dd if=/dae/uuid-${partitionId}/${filename} of=/var/log/${chunkid}.copy${i} bs=100 skip=${offset} count=${endOffset}"\'
                    echo scp ${ipmap[$ssId]}:/opt/emc/caspian/fabric/agent/services/object/main/log/${chunkid}.copy${i} ${chunkid}/${chunkid}.copy${i}
                    scp ${ipmap[$ssId]}:/opt/emc/caspian/fabric/agent/services/object/main/log/${chunkid}.copy${i} ${chunkid}/${chunkid}.copy${i}
                done
                # break for loop
                break
            else
                rm -f $chunkid/${chunkid}.JRContent.${major}
            fi
        else
            echo " !!!!!!----> major not find, timestamp: ${timestamp}"
            break
        fi
    done
}


validate_chunk_data()
{
    retval=1
    if [[ $# < 1 ]]
    then
        echo "validate_chunk_data need arg: chunkid"
        return 1
    fi
    chunkid=$1
    if cmp -s "${chunkid}/${chunkid}.copy1" "${chunkid}/${chunkid}.copy2"
    then
        echo "cmp ${chunkid} OK"
        if grep "$chunkid" "${chunkid}/${chunkid}.copy2"
        then
            mv -v "${chunkid}/${chunkid}.copy2" "${chunkid}/${chunkid}.dat"
            retval=0
        fi
    else
        echo "cmp ${chunkid} BAD"
        retval=2
    fi
    return $retval
}

inject_chunk_data()
{
    if [[ $# < 1 ]]
    then
        echo "validate_chunk_data need arg: chunkid"
        return 1
    fi
    chunkid=$1
    if [ ! -f "${chunkid}/${chunkid}.info" ]
    then
        echo "${chunkid}/${chunkid}.info not find"
        return 2
    fi
    chunk_data="${chunkid}/${chunkid}.dat"
    if [ ! -s "$chunk_data"
    then
        echo "valid chunk data ${chunk_data} not find"
        return 3
    fi
    # get chunk segments info
    eval $(awk '/segments/,/endOffset/{printf "zone=%s\n",$2};/sealedTime:/{printf "sealedTime=\047%s\047\n",$2}' $chunkid/${chunkid}.info)
    echo "zone      : $zone"
    echo "sealedTime: $sealedTime"
    index=11
    dd if=${chunk_data} of=/dae/uuid-${partitionId}/${filename} conv=notrunc bs=1 count=11184800 seek=2885678400 skip=33554400
    python "$PY_CRC32" ${chunk_data} 33554400 11184800
    curl -X PUT "http://${ip_port}/cm/recover/setSegmentChecksum/${cos}/1/${chunkid}/${index}/${checksum}"
    curl -X PUT "http://${ip_port}/cm/recover/removeRecoveryStatus/${cos}/1/${chunkid}/${index}"
}

while read -u 99 chunkid
do
    # search and dump chunk 2 copies
    if [ "x$dump_data" == "xTRUE" ]
    then
        dump_chunk_data "${chunkid}"
    fi
    # validate local chunk data
    if [ "x$validate_data" == "xTRUE" ]
    then
        validate_chunk_data "${chunkid}"
    fi
    # inject local chunk data
    if [ "x$indect_data" == "xTRUE" ]
    then
        inject_chunk_data "${chunkid}"
    fi
    echo '<<  ----------- process finished -----------  >>'
done 99< $chunkidfile

