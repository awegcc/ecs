#!/bin/sh
# Check Missing Jrounal Region

zone=urn:storageos:VirtualDataCenterData:71c744b7-c99e-4a1b-bc09-ff1b1353c74c
dtType=LS
rgId=(076f04fa-6856-4cb2-a07f-5debd82129d5 459c1a0d-568d-46d5-9a16-81d9701733e8 56eee2ce-5947-4fe3-bdca-aeb2d0156403)
#IP of Missing JR zone
host=10.240.29.39

function scan_missing_jr()
{
file="/tmp/JRDT.tmp"
if [ $# -lt 5 ] ; then 
	zone=$1
	DtType=$2
	rgId=$3
	host=$4
fi
echo $zone
echo $DtType
echo $rgId
echo $host

curl -s http://$host:9101/diagnostic/$DtType/0/ | xmllint --format - | grep id | grep $rgId | awk -F"<|>" '{print $3}' > /tmp/JRDT.tmp

while read dtId
do
	#Dump JR to get major and minor for each entry
	curl -s -L "http://$host:9101/diagnostic/PR/1/DumpAllKeys/DIRECTORYTABLE_RECORD?type=JOURNAL_REGION&dtId=${dtId}&zone=${zone}&useStyle=raw" | grep schema |awk '{print $(NF-2),$NF}' > /tmp/OB.JRDump.tmp
	link=$(curl -s -L "http://$host:9101/diagnostic/PR/1/DumpAllKeys/DIRECTORYTABLE_RECORD?type=BPLUSTREE_INFO&dtId=${dtId}&zone=${zone}&useStyle=raw&showvalue=gpb" | grep -B1 schema | grep http | awk -F ' |\n|\r' '{print $1}' )
	lastMajor=$(curl -s -L ${link} | grep subKey: | tail -n 1 | awk -F '\' '{print $3}' | cut -b 4-19 | tr -d $'\r')
	lastMinor=$(curl -s -L ${link} | grep subKey: | tail -n 1 | awk -F '\' '{print $5}' | cut -b 4-19 | tr -d $'\r')
	echo "$dtId"
	while read JR
		do
		echo "JR:$JR"
		echo "lastMajor:$lastMajor lastMinor:$lastMinor"
		JRMajor=$(echo $JR |tr -d $'\r'| awk '{print $1}')
		JRMinor=$(echo $JR |tr -d $'\r'| awk '{print $2}')
		if [[ $((0x$JRMajor)) -lt $((0x$lastMajor)) ]]
		then
			continue
		elif [[ $((0x$JRMajor)) -eq $((0x$lastMajor)) ]] && [[ $((0x$JRMinor)) -le $((0x$lastMinor)) ]]
		then
			continue
		elif [[ $((0x$JRMajor)) -eq $((0x$lastMajor)) ]]
		then
			if [[ $(expr $((0x$JRMinor)) - $((0x$lastMinor))) -ne 1 ]] && [[ $JRMinor != "7fffffffffffffff" ]]
			then
			echo "JR Minor Missing:$dtId $JRMajor $JRMinor"
			echo "dtId:$dtId zone:$zone rgId:$rgId Major:$JRMajor Minor:$JRMinor" >> /tmp/MissingJR.tmp
			fi
		elif [[ $(expr $((0x$JRMajor)) - $((0x$lastMajor))) -eq 1 ]]
		then
			if [[ $lastMinor != "7fffffffffffffff" ]]
			then
			echo "last JR Missing:$dtId $JRMajor $JRMinor"
			echo "dtId:$dtId zone:$zone rgId:$rgId Major:$lastMajor Minor:7fffffffffffffff" >> /tmp/MissingJR.tmp
			fi
			if [[ $JRMinor != "0000000000000000" ]] && [[ $JRMinor != "7fffffffffffffff" ]]
			then
			echo "JR Missing:$dtId $JRMajor $JRMinor"
			echo "dtId:$dtId zone:$zone rgId:$rgId Major:$JRMajor Minor:0000000000000000" >> /tmp/MissingJR.tmp
			fi
		else
			echo "JR Major Missing:$dtId $JRMajor $JRMinor"
			echo "from dtId:$dtId zone:$zone rgId:$rgId Major:$lastMajor Minor:$lastMinor to Major:$JRMajor Minor:$JRMinor" >> /tmp/MissingJR.tmp
		fi		
		lastMajor=$JRMajor
		lastMinor=$JRMinor
	done < /tmp/OB.JRDump.tmp
	
	rm /tmp/OB.JRDump.tmp
	
done < "$file"
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
		DtType=$(echo $MissingJR | awk '{print $2}' | awk -F '_' '{print $(NF-3)}')
		targetdtId=$(echo $MissingJR | awk '{print $2}' | cut -c 6-)
		fromMajor=$(echo $MissingJR |awk '{print $(NF-4)}'|cut -c 7-)
		fromMinor=$(echo $MissingJR |awk '{print $(NF-3)}'|cut -c 7-)
		toMajor=$(echo $MissingJR |awk '{print $(NF-1)}'|cut -c 7-)
		toMinor=$(echo $MissingJR |awk '{print $NF}'|cut -c 7-)
		dtId=$(curl -s http://${host_not_MissingJR}:9101/diagnostic/$DtType/0/ | xmllint --format - | grep id | grep $table | grep $rgId  |awk -F"<|>" '{print $3}')
		#list all the JRs in zone without JR missing
		link=$(curl -s -L "http://${host_not_MissingJR}:9101/diagnostic/PR/1/DumpAllKeys/DIRECTORYTABLE_RECORD?useStyle=raw&showvalue=gpb&type=JOURNAL_REGION&dtId=${dtId}&zone=${zone}&showvalue=gpb" | grep -B1 schema | grep http | awk -F ' |\n|\r' '{print $1}')
		echo "$fromMajor $fromMinor"
		echo "$toMajor $toMinor"
		curl -s -L ${link}| awk '/major '"$fromMajor"' minor '"$fromMinor"'/{f=1;next} /major '"$toMajor"' minor '"$toMinor"'/{f=0} f' | awk 'NR>=6' > /tmp/JRValue.${table}.tmp
	else
		rgId=$(echo $MissingJR | awk '{print $3}' | cut -c 6-)
		zone=$(echo $MissingJR | awk '{print $2}' | cut -c 6-)
		table=$(echo $MissingJR | awk '{print $1}' | awk -F '-' '{print $(NF)}')
		DtType=$(echo $MissingJR | awk '{print $1}' | awk -F '_' '{print $(NF-3)}')
		targetdtId=$(echo $MissingJR | awk '{print $1}' | cut -c 6-)
		Major=$(echo $MissingJR |awk '{print $4}'|cut -c 7-)
		Minor=$(echo $MissingJR |awk '{print $5}'|cut -c 7-)
		dtId=$(curl -s http://${host_not_MissingJR}:9101/diagnostic/$DtType/0/ | xmllint --format - | grep id | grep $table | grep $rgId  |awk -F"<|>" '{print $3}')
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

for rg in ${rgId[@]};
do
	echo "check rg: $rg"
	sh /tmp/JRMissingScan.sh $zone $dtType $rg $host
done
