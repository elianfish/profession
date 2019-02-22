#!/usr/bin/env bash

#set -o nounset
set -o errexit

echo "[INFO]--create emma report user:${BUILD_USER_ID}"
echo "=== expand ec file ==="
wget $EC_PATH || { echo "$ecpath wget failed"; exit 1; }
dstfile=$(basename $EC_PATH) && echo $dstfile
extname=${dstfile##*.} && echo $extname
case $extname in
ec)
     eclist=" -in $dstfile"
     ;;
gz)
     undir=unpack
     [[ -d "$undir" ]] || mkdir $undir
     tar zxvf $dstfile -C $undir

     eclist=""
     for file in $(find $undir/ -name *.ec)
     do
          echo file=$file
          #filename=$(basename $file)
          temp=" -in $file"
          eclist=${eclist}${temp}
     done
     ;;
*)
     echo "*********no info*************"
     exit 1
     ;;
esac

[[ $eclist == "" ]] && { echo "ec file no found" ; exit 1; }
echo eclist=$eclist

echo "=== ini data ==="
BUILD_DATE="`date +%Y%m%d`"
readonly delimiter='\\'
array=(${BUILD_VERSION_PATH//${delimiter}/ })
platform=${array[3]}
pdtname=${array[4]}
buildobj=${array[5]}
buildversion=${array[6]}
svnrevision=$(echo ${buildversion##*-r})
echo "INFO: $platform、$pdtname、$buildobj、$buildversion、$svnrevision"
echo BUILD_DATE=$BUILD_DATE > ${JOB_NAME}.properties
echo PLATFORM=$platform>> ${JOB_NAME}.properties
echo PDT_NAME=$pdtname>> ${JOB_NAME}.properties
echo BUILD_OBJ=$buildobj>> ${JOB_NAME}.properties
echo BUILD_VERSION=$buildversion>> ${JOB_NAME}.properties

echo "=== wget coverage.em file ==="
downurl=http:${BUILD_VERSION_PATH//\\/\/}
wget $downurl/emma/coverage.em || { echo "wget failed"; exit 1; }
wget $downurl/emma/emma.cfg || { echo "wget failed"; exit 1; }

echo "=== start check out source -r$svnrevision ==="
source emma.cfg
echo "Config for the repourl: $repourl" >&2
svn co -r $svnrevision $repourl ${WORKSPACE}/source
flagpath=$(find ${WORKSPACE}/source -name 'coverage.cfg')
[[ $flagpath == "" ]] && { echo "coverage.cfg file no found" ; exit 1; }
#sourcedir=$(dirname $flagpath)/src
sourcedir=${WORKSPACE}/source
echo sourcedir=$sourcedir

echo "=== check  emma.jar file ==="
emmajar=$HOME/emma/emma.jar
if [[ ! -f "$emmajar" ]]; then
     mkdir $HOME/emma/
     pushd $HOME/emma/
     wget http://maven.ysl.com/repositories/central/emma/emma/2.0.5312/emma-2.0.5312.jar
     ln -s emma-2.0.5312.jar emma.jar
     popd
fi

echo "=== make emma report ==="
java -cp $emmajar emma report -r html -in coverage.em$eclist -sp $sourcedir || { echo "java exec failed"; exit 1; }

echo "=== make result pack==="
BUILD_RESULT_DIR=$WORKSPACE/artifacts
mkdir -p ${BUILD_RESULT_DIR}
file_suffix=${BUILD_DATE}-${BUILD_NUMBER}-${BUILD_USER_ID}
[[ "$REPORT_ID" != "none" ]] && file_suffix=${file_suffix}-${REPORT_ID}
tar -zcvf ${BUILD_RESULT_DIR}/coverage-${file_suffix}.tar.gz coverage
filesurl=http://api.report.com/coverage/${platform}/${pdtname}/${buildobj}/${buildversion}/files.info
wget --user=coverage_report --password=drupe68?pace $filesurl || echo "wget ignore 404 ERROR"
if [[ -f "files.info" ]]; then
     echo "coverage-${file_suffix}.tar.gz" >> files.info
else
     echo "coverage-${file_suffix}.tar.gz" > files.info
fi
mv files.info ${BUILD_RESULT_DIR}/files.info
echo "create emma report end"

mkdir -p report && cp coverage/index.html report/index.html
