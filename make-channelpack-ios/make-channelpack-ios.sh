#!/usr/bin/env bash

set -o errexit

# 参数初始化
WORK_DIR=$WORKSPACE
RESULT_DIR=$WORK_DIR/artifacts
CHANNEL_LIST_FILE_NAME=channel.list
CHANNEL_DATA_URL=https://svn.repo.com/doc/appstore/app/${OBJ_NAME}/channel
# 数据初始化
echo "=== ini data ==="
BUILD_DATE="`date +%Y%m%d`"
readonly delimiter='/'
array=(${BUILD_VERSION_PATH//${delimiter}/ })
pdtname=${array[5]}
buildobj=${array[6]}
buildversion=${array[7]}
ipaname=${array[8]}
echo "INFO: $pdtname、$buildobj、$buildversion、$ipaname"
echo BUILD_DATE=$BUILD_DATE > ${JOB_NAME}.properties
echo PDT_NAME=$pdtname>> ${JOB_NAME}.properties
echo BUILD_OBJ=$buildobj>> ${JOB_NAME}.properties
echo BUILD_VERSION=$buildversion>> ${JOB_NAME}.properties
echo IPA_NAME=$ipaname>> ${JOB_NAME}.properties

downurl=$BUILD_VERSION_PATH
curl -O -k ${downurl} || { echo "curl failed"; exit 1; }

[[ -f "$CHANNEL_LIST_FILE_NAME" ]] && rm $CHANNEL_LIST_FILE_NAME
svn export $CHANNEL_DATA_URL $pdtname

[[ -d "$RESULT_DIR" ]] && rm -rdf "$RESULT_DIR"    
mkdir "$RESULT_DIR"  
[[ -d "Payload" ]] && rm -rdf Payload 
unzip $ipaname > unzip.log
dstchangefile=$(find Payload -name "sourceid.dat")
cp -r Payload Payload_origin
for line in $(cat $pdtname/$CHANNEL_LIST_FILE_NAME)   # 读取渠道号文件并进行循环     
do 
    sourceid=`echo ${line} | tr -d '\n\r'`
    echo "replace $dstchangefile before: "    
    cat $dstchangefile     
    echo "$sourceid" > $dstchangefile     
    echo "replace $dstchangefile after: "    
    cat $dstchangefile  
        if [[ -d "$pdtname/$sourceid" ]]; then 
              cp -rf $pdtname/$sourceid/* Payload
          zip -r $RESULT_DIR/${pdtname}_${sourceid}.ipa Payload > zip.log   # 制作渠道包
              rm -rdf Payload
              cp -r Payload_origin Payload
        else
            zip -r $RESULT_DIR/${pdtname}_${sourceid}.ipa Payload > zip.log   # 制作渠道包
        fi     
done 

