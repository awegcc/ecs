#!/bin/sh
#
WORK_FOLDER="/tmp/ECSEE-5230"
PR_OB_LIST=$WORK_FOLDER/"PR_OB.list"
BACKUP_FOLDER=$WORK_FOLDER/backup_info
TMP_FOLDER=$WORK_FOLDER/tmp

rgId="urn:storageos:ReplicationGroupInfo:94d99094-d365-4894-bec1-a7bb1b1377bb:global"
ZONE="urn:storageos:VirtualDataCenterData:74320ff8-92a5-4f0f-a836-a8d702930f52"
HOST_IP=10.69.35.96

function initialization()
{
    mkdir -p $BACKUP_FOLDER
    mkdir -p $TMP_FOLDER
}

function backup()
{
    echo "------back up BPLUSTREE_INFO"
    run_cmd "curl -Ls" "http://${HOST_IP}:9101/${PRID}/DIRECTORYTABLE_RECORD/?dtId=${DTID}&zone=${ZONE}&type=BPLUSTREE_INFO&showvalue=gpb&useStyle=raw"
    curl -Ls "http://${HOST_IP}:9101/${PRID}/DIRECTORYTABLE_RECORD/?dtId=${DTID}&zone=${ZONE}&type=BPLUSTREE_INFO&showvalue=gpb&useStyle=raw" > $BACKUP_FOLDER/${FILE_NAME}.btree_info
    echo "------back up BPLUSTREE_DUMP_MARKER"
    run_cmd "curl -Ls" "http://${HOST_IP}:9101/${PRID}/DIRECTORYTABLE_RECORD/?dtId=${DTID}&zone=${ZONE}&type=BPLUSTREE_DUMP_MARKER&showvalue=gpb&useStyle=raw"
    curl -Ls "http://${HOST_IP}:9101/${PRID}/DIRECTORYTABLE_RECORD/?dtId=${DTID}&zone=${ZONE}&type=BPLUSTREE_DUMP_MARKER&showvalue=gpb&useStyle=raw" > $BACKUP_FOLDER/${FILE_NAME}.dump_marker
    echo "------back up BPLUSTREE_PARSER_MARKER"
    run_cmd "curl -Ls" "http://${HOST_IP}:9101/${PRID}/DIRECTORYTABLE_RECORD/?dtId=${DTID}&zone=${ZONE}&type=BPLUSTREE_PARSER_MARKER&showvalue=gpb&useStyle=raw"
    curl -Ls "http://${HOST_IP}:9101/${PRID}/DIRECTORYTABLE_RECORD/?dtId=${DTID}&zone=${ZONE}&type=BPLUSTREE_PARSER_MARKER&showvalue=gpb&useStyle=raw" > $BACKUP_FOLDER/${FILE_NAME}.parser_marker
    echo "------back up GEOREPLAYER_REPLICATION_CHECKER_MARKER"
    run_cmd "curl -Ls" "http://${HOST_IP}:9101/${PRID}/DIRECTORYTABLE_RECORD/?dtId=${DTID}&zone=${ZONE}&type=GEOREPLAYER_REPLICATION_CHECKER_MARKER&showvalue=gpb&useStyle=raw"
    curl -Ls "http://${HOST_IP}:9101/${PRID}/DIRECTORYTABLE_RECORD/?dtId=${DTID}&zone=${ZONE}&type=GEOREPLAYER_REPLICATION_CHECKER_MARKER&showvalue=gpb&useStyle=raw" > $BACKUP_FOLDER/${FILE_NAME}.georeplayer_replication_marker
    echo "------back up GEOREPLAYER_CONSISTENCY_CHECKER_MARKER"
    run_cmd "curl -Ls" "http://${HOST_IP}:9101/${PRID}/DIRECTORYTABLE_RECORD/?dtId=${DTID}&zone=${ZONE}&type=GEOREPLAYER_CONSISTENCY_CHECKER_MARKER&showvalue=gpb&useStyle=raw"
    curl -Ls "http://${HOST_IP}:9101/${PRID}/DIRECTORYTABLE_RECORD/?dtId=${DTID}&zone=${ZONE}&type=GEOREPLAYER_CONSISTENCY_CHECKER_MARKER&showvalue=gpb&useStyle=raw" > $BACKUP_FOLDER/${FILE_NAME}.georeplayer_consistency_marker
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
        version="$(echo -e "$version" | tr -d '\r\n')"
        #echo remove btree $version
        echo "curl -v -X DELETE \"http://${HOST_IP}:9101/diagnostic/deletebtree/${DTID}/${ZONE}/$version\" "
    done > $TMP_FOLDER/btree_remove.${FILE_NAME}.sh
    echo "+++++ Remove btree"
    run_cmd bash "$TMP_FOLDER/btree_remove.${FILE_NAME}.sh > $TMP_FOLDER/btree_remove.${FILE_NAME}.log"

    echo "==== Check point, wc -l $BTREE_TO_REMOVE must equal grep -c SUCCESS $TMP_FOLDER/btree_remove.${FILE_NAME}.log , need to check if not."
    #if [ "$(wc -l btree.to.remove)" != "$(grep -c SUCCESS btree.remove.log)" ];then
    #    echo "Not all bree delete success. pleanse check log btree.remove.log"
    #else
    #    run_cmd "curl -s" "http://${HOST_IP}:9101/${PRID}/DIRECTORYTABLE_RECORD/?dtId=${DTID}&zone=${ZONE}&type=BPLUSTREE_INFO" | tail -1
    #fi

    echo "==== Check point, Check latest btree after deletion"
    run_cmd "curl -s" "http://${HOST_IP}:9101/${PRID}/DIRECTORYTABLE_RECORD/?dtId=${DTID}&zone=${ZONE}&type=BPLUSTREE_INFO" "| tail -1"

    echo "+++++ Set GEOREPLAYER_REPLICATION_CHECKER_MARKER to major of Bootstrap tree"
    run_cmd "curl -X PUT" "http://${HOST_IP}:9101/gc/setBtreeMarker/GEOREPLAYER_REPLICATION_CHECKER_MARKER/${DTID}/${ZONE}/$MAJOR/0000000000000000"

    echo "+++++ Set GEOREPLAYER_CONSISTENCY_CHECKER_MARKER to major of Bootstrap tree"
    run_cmd "curl -X PUT" "http://${HOST_IP}:9101/gc/setBtreeMarker/GEOREPLAYER_CONSISTENCY_CHECKER_MARKER/${DTID}/${ZONE}/$MAJOR/0000000000000000"

    OCC_PRO=$(grep "occupancyProgress:" $BACKUP_FOLDER/${FILE_NAME}.parser_marker)
    OCC_PRO=${OCC_PRO##* }
    VERSTION=$(grep "version:" $BACKUP_FOLDER/${FILE_NAME}.parser_marker)
    VERSTION=${VERSTION##* }
    echo  "+++++ Set BPLUSTREE_PARSER_MARKER to bootstrap tree major + 1"
    # Note: btree major is bootstrap major + 1, occupancyProgress and version should be the same as backuped BPLUSTREE_PARSER_MARKER
    MAJOR_NUM=$(echo $MAJOR | awk '{major_d=strtonum("0x"$1);printf("%0x", major_d)}')
    MAJOR_ADD_1=$(echo $MAJOR | awk '{major_d=strtonum("0x"$1);majoradd=major_d+1; printf("%0x", majoradd)}')
    MAJOR_ADD_1_S=${MAJOR/$MAJOR_NUM/$MAJOR_ADD_1}

    run_cmd "curl -I -X PUT" "http://${HOST_IP}:9101/gc/setBtreeMarker/BPLUSTREE_PARSER_MARKER/${DTID}/${ZONE}/$MAJOR_ADD_1_S/${OCC_PRO}/${VERSTION}/"


    echo "+++++ Cleanup GC_REF_COLLECTION Key for reverted btree"
    CT_IDS=$TMP_FOLDER/ct_id.${FILE_NAME}
    curl -Ls "http://$HOST_IP:9101/diagnostic/CT/1/" | xmllint --format - | grep '<id>' | awk -F '<|>' '{print $3}' > $CT_IDS
    for ctId in `cat $CT_IDS`
    do
       prId=$(curl -L -s "http://${HOST_IP}:9101/diagnostic/PR/1/DumpAllKeys/GC_REF_COLLECTION/?type=BTREE&ctId=${ctId}&zone=${ZONE}&rgId=${rgId}&obId=${DTID}&useStyle=raw" | grep -B1 schema | grep http | awk -F '/' '{print $4}' | awk -F "PR_" '{print $2}' | awk -F "_128" '{print $1}')
       echo "curl -L -X DELETE \"http://${HOST_IP}:9101/diagnostic/deletegcrefcollectionkey/${prId}/BTREE/${ctId}/${ZONE}/${rgId}/${DTID}\" -v "
    done > $TMP_FOLDER/clear_gc_ref.${FILE_NAME}.sh

    run_cmd bash $TMP_FOLDER/clear_gc_ref.${FILE_NAME}.sh

    echo "===check proint. Confirm GC_REF_COLLECTION Key for reverted btree has been cleaned up"
    ALL_GC_REF=$TMP_FOLDER/all_gc_ref_dump.${FILE_NAME}
    run_cmd "curl -Ls" "http://${HOST_IP}:9101/diagnostic/PR/1/DumpAllKeys/GC_REF_COLLECTION/?type=BTREE&useStyle=raw" " | grep schema > $ALL_GC_REF"
    echo "blow should NOT be 0"
    run_cmd "cat $ALL_GC_REF" " | wc -l"
    echo "blow should be 0 here"
    run_cmd grep "${DTID} $ALL_GC_REF" " | grep -c ${ZONE}"

}


initialization
while read line
do
    PR_OB=$(echo $line)
    PRID=${PR_OB%% *}
    DTID=${PR_OB##* }
    PR_NUM=${PRID#*__}
    PR_NUM=${PR_NUM/:/}
    DT_NUM=${DTID#*_}
    DT_NUM=${DT_NUM#*_}
    DT_NUM=${DT_NUM/:/}
    FILE_NAME=$PR_NUM-$DT_NUM-`date +"%s"`
    echo ""
    echo "******** start $PR_OB   ******"
    echo ""

   backup
   delete_btree
done < $PR_OB_LIST


