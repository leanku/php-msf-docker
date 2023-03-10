#!/bin/bash

######## 合并多个扩展安装文件  ############

TOOLS_DIR=$(dirname "`readlink -f $0`")

pushd "${TOOLS_DIR}" > /dev/null

EXTS=$(ls *.sh)

> ./extension.sh
for var in ${EXTS}
do
    if [ "${var}" != "merge.sh" ] && [ "${var}" != "extension.sh" ]; then
       cat "${var}" >> ./extension.sh
    fi
done

popd  > /dev/null
