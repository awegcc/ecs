#/bin/sh
#
if [[ $# < 1 ]]
then
    ip_port=$(netstat -ntl | awk '/:9101/{print $4;exit}')
else
    ip_port="$1:9101"
fi

postfix='DELETE_JOB_TABLE_KEY?type=CLEANUP_JOB&objectId=aa&maxkeys=1&useStyle=raw'
url_addr="http://${ip_port}/diagnostic/OB/0/"

curl -s "$url_addr" | xmllint --format - | awk -F'[<>?]' '/table_detail_link/{print $3}' | while read url
do
    curl -s -L "${url}${postfix}" | grep schemaType
done > cleanupjobs.lst

#sh /tmp/cleanup_job_command.sh.2 > /tmp/cleanupjob.tmp

#grep schemaType /tmp/cleanupjob.tmp | awk '{print $4}' | sort -n | head -3

