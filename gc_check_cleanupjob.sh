#!/bin/sh

ip_port=$(netstat -ntl | awk '/:9101/{print $4;exit}')
date_str=$(date +"%Y%m%d-%H%M")
curl http://${ip_port}/diagnostic/OB/0/ | xmllint --format - | awk -F'[<?>]' '/table_detail_link/{print $3}' > All_OB_link

while read ob_url
do
    curl -L "${ob_url}DELETE_JOB_TABLE_KEY?type=CLEANUP_JOB&objectId=aa&maxkeys=1&useStyle=raw"
done < All_OB_link > cleanupjob.$date_str

# Find the earliest expire time for fetched cleanup jobs
awk 'BEGIN{cts=systime()} /schemaType/{sts=substr($4,1,10);printf("%d  %s delay %.1f day\n",$4,strftime("%Y-%m-%d %H:%M:%S",sts),(cts-sts)/(3600*24) )}' cleanupjob.$date_str | sort -n | head -5

echo "result saved in cleanupjob.$date_str"
exit
# If the earliest expire time is long time before current time, it's possible cleanup jobs are blocked in this OB table or there are huge backlog of cleanup jobs (i.e. DeleteJobScanner cannot catch up with the speed of generating cleanup jobs).
# Find which OB table the earliest expire time belongs to. In this example, it's OB_73_128_0.

grep -B1 1479361654707 cleanupjob.tmp
http://10.247.195.130:9101/urn:storageos:OwnershipInfo:15519928-e6ea-4688-b9fe-813c86104730_6599ff72-89cf-4daa-aa91-d8b96196293f_OB_73_128_0:/
schemaType DELETE_JOB_TABLE_KEY expireTime 1479361654707 type CLEANUP_JOB objectIndexKey schemaType OBJECT_TABLE_KEY objectId df2a2a3e0dccd7134e8057d398e572b338cff189954ad50e722dc8f3d579f22f type UPDATE sequence 0 keyVersion version22 indexSequence 1 versionId 0

# Get the first key again, if it is identical to the key in /tmp/cleanupjob.tmp, it's blocked. In this case, it's blocked because the first key does not change.

curl -L "http://10.247.195.130:9101/urn:storageos:OwnershipInfo:15519928-e6ea-4688-b9fe-813c86104730_6599ff72-89cf-4daa-aa91-d8b96196293f_OB_73_128_0:/DELETE_JOB_TABLE_KEY?type=CLEANUP_JOB&objectId=aa&maxkeys=1&useStyle=raw" | grep schema
schemaType DELETE_JOB_TABLE_KEY expireTime 1479361654707 type CLEANUP_JOB objectIndexKey schemaType OBJECT_TABLE_KEY objectId df2a2a3e0dccd7134e8057d398e572b338cff189954ad50e722dc8f3d579f22f type UPDATE sequence 0 keyVersion version22 indexSequence 1 versionId 0

