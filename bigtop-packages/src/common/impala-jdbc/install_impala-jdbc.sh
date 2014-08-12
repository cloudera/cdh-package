#!/bin/bash

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

usage() {
  echo "
usage: $0 <options>
  Required not-so-options:
     --build-dir=DIR             path to hive/build/dist
     --prefix=PREFIX             path to install into
     --extra-dir=DIR             path to Bigtop distribution files

  "
  exit 1
}

OPTS=$(getopt \
  -n $0 \
  -o '' \
  -l 'prefix:' \
  -l 'extra-dir:' \
  -l 'build-dir:' -- "$@")

if [ $? != 0 ] ; then
    usage
fi

eval set -- "$OPTS"
while true ; do
    case "$1" in
        --prefix)
        PREFIX=$2 ; shift 2
        ;;
        --build-dir)
        BUILD_DIR=$2 ; shift 2
        ;;
        --extra-dir)
        EXTRA_DIR=$2 ; shift 2
        ;;
        --)
        shift ; break
        ;;
        *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
done

for var in PREFIX BUILD_DIR ; do
  if [ -z "$(eval "echo \$$var")" ]; then
    echo Missing param: $var
    usage
  fi
done

. ${EXTRA_DIR}/packaging_functions.sh

LIB_DIR=${PREFIX}/usr/lib/impala-jdbc

JAR_DIR=${BUILD_DIR}/src/build/impala-jdbc-*-cdh*/lib

install -d -m 0755 ${LIB_DIR}
INCLUDED_ARTIFACTS="commons-logging hive-common hive-jdbc hive-metastore hive-service libfb303 libthrift log4j slf4j"
for artifact in ${INCLUDED_ARTIFACTS}; do
    cp ${JAR_DIR}/${artifact}*.jar ${LIB_DIR}/
done

ln -s ../hadoop/hadoop-common.jar ${LIB_DIR}/

# Cloudera specific
install -d -m 0755 ${LIB_DIR}/cloudera
cp cloudera/cdh_version.properties ${LIB_DIR}/cloudera/

internal_versionless_symlinks ${LIB_DIR}/hive*.jar

