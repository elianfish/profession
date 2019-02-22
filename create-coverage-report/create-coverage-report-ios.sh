#!/usr/bin/env bash

#set -o nounset
set -o errexit

# 参数初始化
WORK_DIR=$WORKSPACE
COVERAGE_DATA_PATH=$WORK_DIR/coveragedata
LCOV_INFO=$WORK_DIR/coverage.info
GCNO_PATH=$WORK_DIR/gcno
GCDA_PATH=$WORK_DIR/gcda
COVERAGE_RESULT_PATH=$WORK_DIR/coverage
BUILD_RESULT_DIR=$WORK_DIR/artifacts
# 数据初始化
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

tarfile="${pdtname}_coverage_data.tar.gz"
[[ "$IS_SIMULATOR" == "true" ]] && tarfile="${pdtname}_simulator_coverage_data.tar.gz"
# 下载.*_coverage.tar.gz或者.*_simulator_coverage.tar.gz,解压到coveragedata
echo "=== wget  ${tarfile} ==="
downurl=http:${BUILD_VERSION_PATH//\\/\/}
curl -O -k ${downurl}/coverage.cfg || { echo "curl failed"; exit 1; }
curl -O -k ${downurl}/${tarfile} || { echo "curl failed"; exit 1; }
[[ -d "$COVERAGE_DATA_PATH" ]] || mkdir -p $COVERAGE_DATA_PATH
tar zxvf $tarfile -C $COVERAGE_DATA_PATH 
# 解析coverage.cfg,获取代码
echo "=== checkout source code ==="
echo "Reading config...." >&2
source coverage.cfg
echo "Config for the sourcedir: $sourcedir" >&2
echo "Config for the repourl: $repourl" >&2
[[ -d "$sourcedir" ]] && rm -rf $sourcedir
svn co -r $svnrevision $repourl $sourcedir
pushd $sourcedir
[[ `pod --version` != 0.* ]] && REPO_UPDATE_PARAM='--repo-update'
[[ -e "Podfile" ]] && [[ -e "Podfile.lock" ]] && time pod update
[[ -e "Podfile.lock" ]] || ( [[ -e "Podfile" ]] && time pod install $REPO_UPDATE_PARAM )
popd
# 获取*.gcno到gcno目录 
echo "=== get gcno file ==="
[[ -d "$GCNO_PATH" ]] && rm -rf $GCNO_PATH
#mkdir -p  $GCNO_PATH && find $COVERAGE_DATA_PATH/ -name *.gcno -exec cp -P {} gcno/ \;
gcnodata=`find $COVERAGE_DATA_PATH/ -name *.gcno`
SAVEIFS=$IFS
IFS=$(echo -en "\n\b")
for gcnofile in $gcnodata 
do
    filepath="$(dirname "$gcnofile")"
    destdir="$(basename "$filepath")"
    [[ -d "$GCNO_PATH/$destdir" ]] || mkdir -p $GCNO_PATH/$destdir
    echo "$gcnofile $GCNO_PATH/$destdir"
    cp "$gcnofile" "$GCNO_PATH/$destdir"
done
IFS=$SAVEIFS
# 下载gcda.tar.gz包，解压到gcda目录
echo "=== get gcda file ==="
curl -O -k $GCDA_URL || { echo "curl failed"; exit 1; }
dstfile=$(basename $GCDA_URL) && echo $dstfile
[[ -d "$GCDA_PATH" ]] && rm -rf $GCDA_PATH
mkdir -p $GCDA_PATH
tar zxvf $dstfile -C $GCDA_PATH
# 循环gcda下的子目录childgcda：
[[ -d "info" ]] && rm -rf info 
mkdir info
[[ -f "gcnofilenofound.list" ]] && rm gcnofilenofound.list
for childgcno in $(ls $GCNO_PATH)
do
    for childgcda in $(ls $GCDA_PATH)
    do
        echo "=== lcov info/${childgcno}-${childgcda}.info  ==="
        [[ -d "temp" ]] && rm -rf temp
        mkdir -p temp
        for gcdafile in $(find $GCDA_PATH/$childgcda -name "*.gcda")
        do
            filefullname=$(basename "$gcdafile")
            gcdafilename="${filefullname%.*}"
            if [[ -f "$GCNO_PATH/$childgcno/${gcdafilename}.gcno" ]] ; then
                cp "$GCDA_PATH/$childgcda/${gcdafilename}.gcda" temp
                cp "$GCNO_PATH/$childgcno/${gcdafilename}.gcno" temp
            else
                echo "***** $GCNO_PATH/${gcdafilename}.gcno no found *****" >> gcnofilenofound.list
            fi
        done

        lcov -c -d temp --rc lcov_branch_coverage=1 --base-directory $sourcedir --ignore-errors gcov --ignore-errors source --ignore-errors graph -o info/${childgcno}-${childgcda}.info
        if [ -s "info/${childgcno}-${childgcda}.info" ];then
            lcov -r info/${childgcno}-${childgcda}.info "/Applications/Xcode.app/*" --rc lcov_branch_coverage=1 -d temp/ -o info/${childgcno}-${childgcda}.info
        fi   
    done
done
# 合并info文件
echo "=== combine info file ==="
for infofile in $(find info -name "*.info")
do
  echo file=$infofile
  if [ -s $infofile ];then  
     arg=" --add-tracefile $infofile"
     infolist=${infolist}${arg}
  else
    echo "$infofile size is zero,ignored."
  fi
done
echo infolist=$infolist
[[ $infolist == "" ]] && { echo "info file no found" ; exit 1; }
lcov --rc lcov_branch_coverage=1 ${infolist} --output-file coverage.info
# 生成报告
echo "=== generate coverage report ==="
genhtml --function-coverage --branch-coverage coverage.info -o coverage
# 将报告打成gz包
echo "=== make tar pack ==="
mkdir -p ${BUILD_RESULT_DIR}
file_prefix=coverage
[[ "$IS_SIMULATOR" == "true" ]] && file_prefix=simulator-coverage
file_suffix=${BUILD_DATE}-${BUILD_NUMBER}-${BUILD_USER_ID}
[[ "$REPORT_ID" != "none" ]] && file_suffix=${file_suffix}-${REPORT_ID}
tar -zcvf ${BUILD_RESULT_DIR}/${file_prefix}-${file_suffix}.tar.gz coverage

echo "create coverage report end"
mkdir -p report && cp coverage/*.html coverage/*.png coverage/*.css report/
