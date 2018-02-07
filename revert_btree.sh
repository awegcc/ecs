#!/bin/sh
#
WORK_FOLDER="$(pwd)"
PR_OB_LIST="$WORK_FOLDER/PR_OB.list"
BACKUP_FOLDER="$WORK_FOLDER/backup_info"
TMP_FOLDER="$WORK_FOLDER/tmp"

if [[ $# < 1 ]]
then
    ip_port=$(netstat -ntl | awk '/:9101/{print $4;exit}')
else
    ip_port="${1}:9101"
fi

ZONE='urn:storageos:VirtualDataCenterData:71c744b7-c99e-4a1b-bc09-ff1b1353c74c'

function initialization()
{
    mkdir -p $BACKUP_FOLDER
    mkdir -p $TMP_FOLDER
}

function backup()
{
    echo "------back up BPLUSTREE_INFO"
    run_cmd "curl -Ls" "http://${ip_port}/${PRID}/DIRECTORYTABLE_RECORD/?dtId=${DTID}&zone=${ZONE}&type=BPLUSTREE_INFO&showvalue=gpb&useStyle=raw"
    curl -Ls "http://${ip_port}/${PRID}/DIRECTORYTABLE_RECORD/?dtId=${DTID}&zone=${ZONE}&type=BPLUSTREE_INFO&showvalue=gpb&useStyle=raw" > $BACKUP_FOLDER/${FILE_NAME}.btree_info
    echo "------back up BPLUSTREE_DUMP_MARKER"
    run_cmd "curl -Ls" "http://${ip_port}/${PRID}/DIRECTORYTABLE_RECORD/?dtId=${DTID}&zone=${ZONE}&type=BPLUSTREE_DUMP_MARKER&showvalue=gpb&useStyle=raw"
    curl -Ls "http://${ip_port}/${PRID}/DIRECTORYTABLE_RECORD/?dtId=${DTID}&zone=${ZONE}&type=BPLUSTREE_DUMP_MARKER&showvalue=gpb&useStyle=raw" > $BACKUP_FOLDER/${FILE_NAME}.dump_marker
    echo "------back up BPLUSTREE_PARSER_MARKER"
    run_cmd "curl -Ls" "http://${ip_port}/${PRID}/DIRECTORYTABLE_RECORD/?dtId=${DTID}&zone=${ZONE}&type=BPLUSTREE_PARSER_MARKER&showvalue=gpb&useStyle=raw"
    curl -Ls "http://${ip_port}/${PRID}/DIRECTORYTABLE_RECORD/?dtId=${DTID}&zone=${ZONE}&type=BPLUSTREE_PARSER_MARKER&showvalue=gpb&useStyle=raw" > $BACKUP_FOLDER/${FILE_NAME}.parser_marker
    echo "------back up GEOREPLAYER_REPLICATION_CHECKER_MARKER"
    run_cmd "curl -Ls" "http://${ip_port}/${PRID}/DIRECTORYTABLE_RECORD/?dtId=${DTID}&zone=${ZONE}&type=GEOREPLAYER_REPLICATION_CHECKER_MARKER&showvalue=gpb&useStyle=raw"
    curl -Ls "http://${ip_port}/${PRID}/DIRECTORYTABLE_RECORD/?dtId=${DTID}&zone=${ZONE}&type=GEOREPLAYER_REPLICATION_CHECKER_MARKER&showvalue=gpb&useStyle=raw" > $BACKUP_FOLDER/${FILE_NAME}.georeplayer_replication_marker
    echo "------back up GEOREPLAYER_CONSISTENCY_CHECKER_MARKER"
    run_cmd "curl -Ls" "http://${ip_port}/${PRID}/DIRECTORYTABLE_RECORD/?dtId=${DTID}&zone=${ZONE}&type=GEOREPLAYER_CONSISTENCY_CHECKER_MARKER&showvalue=gpb&useStyle=raw"
    curl -Ls "http://${ip_port}/${PRID}/DIRECTORYTABLE_RECORD/?dtId=${DTID}&zone=${ZONE}&type=GEOREPLAYER_CONSISTENCY_CHECKER_MARKER&showvalue=gpb&useStyle=raw" > $BACKUP_FOLDER/${FILE_NAME}.georeplayer_consistency_marker
}

function run_cmd()
{
    echo $1 \"$2\" "$3"
    echo ""
}

function delete_btree()
{
    MAJOR=$(grep schema $BACKUP_FOLDER/${FILE_NAME}.btree_info | head -1 | awk '{print $10}')
    echo "+++++Select btree to remove: $MAJOR"
    BTREE_TO_REMOVE=$TMP_FOLDER/btree_to_remove.${FILE_NAME}
    grep schema $BACKUP_FOLDER/${FILE_NAME}.btree_info | awk '$(NF-2)>major {print $(NF-2)"/"$NF}' major="$MAJOR" > $BTREE_TO_REMOVE

    for version in `cat $BTREE_TO_REMOVE`
    do
        version=${version%'\r'}
        #echo remove btree $version
        echo "curl -v -X DELETE \"http://${ip_port}/diagnostic/deletebtree/${DTID}/${ZONE}/$version\" "
    done > $TMP_FOLDER/btree_remove.${FILE_NAME}.sh
    echo "+++++ Remove btree"
    run_cmd bash "$TMP_FOLDER/btree_remove.${FILE_NAME}.sh > $TMP_FOLDER/btree_remove.${FILE_NAME}.log"

    echo "==== Check point, wc -l $BTREE_TO_REMOVE must equal grep -c SUCCESS $TMP_FOLDER/btree_remove.${FILE_NAME}.log , need to check if not."
    #if [ "$(wc -l btree.to.remove)" != "$(grep -c SUCCESS btree.remove.log)" ];then
    #    echo "Not all bree delete success. pleanse check log btree.remove.log"
    #else
    #    run_cmd "curl -s" "http://${ip_port}/${PRID}/DIRECTORYTABLE_RECORD/?dtId=${DTID}&zone=${ZONE}&type=BPLUSTREE_INFO" | tail -1
    #fi

    echo "==== Check point, Check latest btree after deletion"
    run_cmd "curl -s" "http://${ip_port}/${PRID}/DIRECTORYTABLE_RECORD/?dtId=${DTID}&zone=${ZONE}&type=BPLUSTREE_INFO" "| tail -1"

    echo "+++++ Set GEOREPLAYER_REPLICATION_CHECKER_MARKER to major of Bootstrap tree"
    run_cmd "curl -X PUT" "http://${ip_port}/gc/setBtreeMarker/GEOREPLAYER_REPLICATION_CHECKER_MARKER/${DTID}/${ZONE}/$MAJOR/0000000000000000"

    echo "+++++ Set GEOREPLAYER_CONSISTENCY_CHECKER_MARKER to major of Bootstrap tree"
    run_cmd "curl -X PUT" "http://${ip_port}/gc/setBtreeMarker/GEOREPLAYER_CONSISTENCY_CHECKER_MARKER/${DTID}/${ZONE}/$MAJOR/0000000000000000"

    OCC_PRO=$(grep "occupancyProgress:" $BACKUP_FOLDER/${FILE_NAME}.parser_marker)
    OCC_PRO=${OCC_PRO##* }
    VERSTION=$(grep "version:" $BACKUP_FOLDER/${FILE_NAME}.parser_marker)
    VERSTION=${VERSTION##* }
    echo  "+++++ Set BPLUSTREE_PARSER_MARKER to bootstrap tree major + 1"
    # Note: btree major is bootstrap major + 1, occupancyProgress and version should be the same as backuped BPLUSTREE_PARSER_MARKER
    MAJOR_ADD_1=$(awk -v n=$MAJOR 'BEGIN{printf("%016x\n",strtonum("0x"n)+1)}')

    run_cmd "curl -I -X PUT" "http://${ip_port}/gc/setBtreeMarker/BPLUSTREE_PARSER_MARKER/${DTID}/${ZONE}/$MAJOR_ADD_1/${OCC_PRO}/${VERSTION}/"


    echo "+++++ Cleanup GC_REF_COLLECTION Key for reverted btree"
    CT_IDS=$TMP_FOLDER/ct_id.${FILE_NAME}
    curl -Ls "http://${ip_port}/diagnostic/CT/1/" | xmllint --format - | awk -F'[<>]' '/id/{print $3}' > $CT_IDS
    gc_ref_url="http://${ip_port}/diagnostic/PR/1/DumpAllKeys/GC_REF_COLLECTION/"
    for ctId in `cat $CT_IDS`
    do
       prId=$(curl -L -s "${gc_ref_url}?type=BTREE&ctId=${ctId}&zone=${ZONE}&rgId=${rgId}&obId=${DTID}&useStyle=raw"| grep -B1 schemaT | awk -F'_' '/http/{print $4}')
       echo "curl -v -L -X DELETE \"http://${ip_port}/diagnostic/deletegcrefcollectionkey/${prId}/BTREE/${ctId}/${ZONE}/${rgId}/${DTID}\" "
    done > $TMP_FOLDER/clear_gc_ref.${FILE_NAME}.sh

    run_cmd bash $TMP_FOLDER/clear_gc_ref.${FILE_NAME}.sh

    echo "===check proint. Confirm GC_REF_COLLECTION Key for reverted btree has been cleaned up"
    ALL_GC_REF=$TMP_FOLDER/all_gc_ref_dump.${FILE_NAME}
    run_cmd "curl -Ls" "http://${ip_port}/diagnostic/PR/1/DumpAllKeys/GC_REF_COLLECTION/?type=BTREE&useStyle=raw" " | grep schema > $ALL_GC_REF"
    echo "blow should NOT be 0"
    run_cmd "cat $ALL_GC_REF" " | wc -l"
    echo "blow should be 0 here"
    run_cmd grep "${DTID} $ALL_GC_REF" " | grep -c ${ZONE}"

}


initialization
while read PRID DTID
do
    FILE_NAME=${PRID:66:-1}-${DTID:102:-1}-$(date +'%Y%m%d_%H%M')
    rgId="urn:storageos:ReplicationGroupInfo:${DTID:65:36}:global"
    echo ""
    echo "******** start $DTID   ******"
    echo ""

    backup
    delete_btree
done < $PR_OB_LIST
