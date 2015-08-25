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

set -e

usage() {
  echo "
usage: $0 <options>
  Required not-so-options:
     --build-dir=DIR             path to parquet18 tarball with binaries
     --prefix=PREFIX             path to install into

  Optional options:
     --lib-dir=DIR               path to install parquet18 jar files
     ... [ see source for more similar options ]
  "
  exit 1
}

OPTS=$(getopt \
  -n $0 \
  -o '' \
  -l 'prefix:' \
  -l 'lib-dir:' \
  -l 'distro-dir:' \
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
        --lib-dir)
        LIB_DIR=$2 ; shift 2
        ;;
        --distro-dir)
        DISTRO_DIR=$2 ; shift 2
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

. ${DISTRO_DIR}/packaging_functions.sh

LIB_DIR=${LIB_DIR:-/usr/lib/parquet}
HADOOP_HOME=${HADOOP_HOME:-/usr/lib/hadoop}
RELATIVE_PATH='../parquet' # LIB_DIR relative to HADOOP_HOME

# install parquet-tools first because it unpacks the lib/ folder
install -d -m 0755 ${PREFIX}/${LIB_DIR}/bin

#Adding this line to make sure that these dirs are created even if we do not
#build parquet-tools 
mkdir -p  ../lib ${PREFIX}/${LIB_DIR}/lib

ln -s ../lib ${PREFIX}/${LIB_DIR}/bin/lib
chmod 755 ${PREFIX}/${LIB_DIR}/lib

# move everything into the LIB_DIR/lib folder created above
install -d -m 0755 $PREFIX/$HADOOP_HOME

versions='s#-[0-9.]\+-cdh[0-9\-\.]*[0-9]\(-beta-[0-9]\+\)\?\(-SNAPSHOT\)\?##'

#We want the javadoc and source jars for just parquet-format 
p_format_jarlist=`find $BUILD_DIR -name parquet-format*.jar | egrep -i 'javadoc|source'`
for jar in `find $BUILD_DIR -name parquet*.jar | grep -v 'sources.jar' | grep -v 'javadoc.jar' | grep -v 'tests.jar' | grep -v 'original-parquet'` $p_format_jarlist; do
    # copy the jar if it isn't already in LIB_DIR/lib
    [ -f "${PREFIX}/${LIB_DIR}/lib/`basename ${jar}`" ] || cp $jar $PREFIX/$LIB_DIR/lib/
    versionless=`echo \`basename ${jar}\` | sed -e ${versions}`
    ln -fs lib/`basename ${jar}` ${PREFIX}/${LIB_DIR}/apache-${versionless}
    ln -fs ${RELATIVE_PATH}/apache-${versionless} $PREFIX/$HADOOP_HOME/
done

cp ${BUILD_DIR}/LICENSE ${PREFIX}/${LIB_DIR}/LICENSE.parquet18
cp ${BUILD_DIR}/NOTICE ${PREFIX}/${LIB_DIR}/NOTICE.parquet18

[ -f ${PREFIX}/${LIB_DIR}/lib/hadoop-client*.jar ] &&  rm ${PREFIX}/${LIB_DIR}/lib/hadoop-client*.jar

# Cloudera specific - changing the name of the cdh_version.properties file
#so as to not clash with the same filename for parquet
install -d -m 0755 $PREFIX/$LIB_DIR/cloudera
cp cloudera/cdh_version.properties $PREFIX/$LIB_DIR/cloudera/cdh_version.properties.parquet18

external_versionless_symlinks 'parquet' ${PREFIX}/${LIB_DIR}/lib/
