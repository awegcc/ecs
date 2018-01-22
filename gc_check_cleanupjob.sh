#!/bin/sh

# Generate commands to get first cleanup of each OB table
curl http://`hostname`:9101/diagnostic/OB/0/ | xmllint --format - | grep table_detail_link | awk -F"[<|>|?]" '{print "echo \""$3"\"\n""curl -L \""$3"DELETE_JOB_TABLE_KEY?type=CLEANUP_JOB&objectId=aa&maxkeys=1&useStyle=raw\""}' > cleanupjob_command.sh

# Execute the generated script
sh cleanup_job_command.sh > cleanupjob.tmp

# Find the earliest expire time for fetched cleanup jobs

awk '/schemaType/{print $4}' cleanupjob.tmp | sort -n | head -3
1479361654707
1479361973815
1479362655633

# If the earliest expire time is long time before current time, it's possible cleanup jobs are blocked in this OB table or there are huge backlog of cleanup jobs (i.e. DeleteJobScanner cannot catch up with the speed of generating cleanup jobs).

date -d @1479361654.707
Thu Nov 17 05:47:34 UTC 2016
date
Sun Nov 27 07:19:49 UTC 2016

# Find which OB table the earliest expire time belongs to. In this example, it's OB_73_128_0.

grep -B1 1479361654707 /tmp/cleanupjob.tmp
http://10.247.195.130:9101/urn:storageos:OwnershipInfo:15519928-e6ea-4688-b9fe-813c86104730_6599ff72-89cf-4daa-aa91-d8b96196293f_OB_73_128_0:/
schemaType DELETE_JOB_TABLE_KEY expireTime 1479361654707 type CLEANUP_JOB objectIndexKey schemaType OBJECT_TABLE_KEY objectId df2a2a3e0dccd7134e8057d398e572b338cff189954ad50e722dc8f3d579f22f type UPDATE sequence 0 keyVersion version22 indexSequence 1 versionId 0

# Get the first key again, if it is identical to the key in /tmp/cleanupjob.tmp, it's blocked. In this case, it's blocked because the first key does not change.

curl -L "http://10.247.195.130:9101/urn:storageos:OwnershipInfo:15519928-e6ea-4688-b9fe-813c86104730_6599ff72-89cf-4daa-aa91-d8b96196293f_OB_73_128_0:/DELETE_JOB_TABLE_KEY?type=CLEANUP_JOB&objectId=aa&maxkeys=1&useStyle=raw" | grep schema
schemaType DELETE_JOB_TABLE_KEY expireTime 1479361654707 type CLEANUP_JOB objectIndexKey schemaType OBJECT_TABLE_KEY objectId df2a2a3e0dccd7134e8057d398e572b338cff189954ad50e722dc8f3d579f22f type UPDATE sequence 0 keyVersion version22 indexSequence 1 versionId 0
