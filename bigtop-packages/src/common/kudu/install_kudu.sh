#!/bin/bash -x
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

set -ex

usage() {
  echo "
usage: $0 <options>
  Required not-so-options:
     --build-dir=DIR             path to Kudu build directory
     --prefix=PREFIX             path to install into
     --extra-dir=DIR             path to extra packaging files
  "
  exit 1
}

OPTS=$(getopt \
  -n $0 \
  -o '' \
  -l 'prefix:' \
  -l 'build-dir:' \
  -l 'bin-dir:' \
  -l 'doc-dir:' \
  -l 'man-dir:' \
  -l 'conf-dir:' \
  -l 'native-lib-dir:' \
  -l 'system-include-dir:' \
  -l 'system-lib-dir:' \
  -l 'extra-dir:' \
  -- "$@")

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
        --bin-dir)
        BIN_DIR=$2 ; shift 2
        ;;
        --man-dir)
        MAN_DIR=$2 ; shift 2
        ;;
        --doc-dir)
        DOC_DIR=$2 ; shift 2
        ;;
        --conf-dir)
        CONF_DIR=$2 ; shift 2
        ;;
        --native-lib-dir)
        NATIVE_LIB_DIR=$2 ; shift 2
        ;;
        --system-include-dir)
        SYSTEM_INCLUDE_DIR=$2 ; shift 2
        ;;
        --system-lib-dir)
        SYSTEM_LIB_DIR=$2 ; shift 2
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

for var in PREFIX BUILD_DIR; do
  if [ -z "$(eval "echo \$$var")" ]; then
    echo Missing param: $var
    usage
  fi
done

. ${EXTRA_DIR}/packaging_functions.sh

ETC_DIR=${ETC_DIR:-$PREFIX/etc}
LIB_DIR=${LIB_DIR:-$PREFIX/usr/lib/kudu}
BIN_DIR=${BIN_DIR:-$PREFIX/usr/bin}
DOC_DIR=${DOC_DIR:-$PREFIX/usr/share/doc/kudu}
MAN_DIR=${MAN_DIR:-$PREFIX/usr/man}
CONF_DIR=${CONF_DIR:-$PREFIX/etc/kudu/conf.dist}
NATIVE_LIB_DIR=${NATIVE_LIB_DIR:-lib}
SYSTEM_INCLUDE_DIR=${SYSTEM_INCLUDE_DIR:-/usr/include}
SYSTEM_LIB_DIR=${SYSTEM_LIB_DIR:-/usr/lib}

install -d -m 0755 ${LIB_DIR}

executables="kudu-tablet_server kudu-master kudu-fs_dump kudu-ts-cli \
             log-dump kudu-fs_list kudu-ksck kudu-pbc-dump cfile-dump"
# Other files that are not tests, not protoc, and not not included:
#create-demo-table insert-generated-rows log-dump ms3_demo rle rpc-bench rwlock-perf tpch1 wal_hiccup
install -d -m 0755 ${LIB_DIR}/bin-release
install -d -m 0755 ${LIB_DIR}/bin-debug
for executable in ${executables}; do
    cp ${BUILD_DIR}/build/release/${executable} ${LIB_DIR}/bin-release/
    cp ${BUILD_DIR}/build/fastdebug/${executable} ${LIB_DIR}/bin-debug/
done

# now, create a defaults file
install -d -m 0755 ${ETC_DIR}/default
cat > ${ETC_DIR}/default/kudu <<__EOT__
KUDU_LOG_DIR=/var/log/kudu
KUDU_MASTER_ARGS="-log_dir \${KUDU_LOG_DIR}"
KUDU_TABLET_SERVER_ARGS="-log_dir \${KUDU_LOG_DIR}"
__EOT__
chmod 0644 ${ETC_DIR}/default/kudu

# create wrapper scripts in /usr/bin for user-facing executables
install -d -m 0755 ${BIN_DIR}
DO_EXEC="exec "
wrappers="kudu-tablet_server kudu-master kudu-fs_dump kudu-ts-cli
          log-dump kudu-fs_list kudu-ksck kudu-pbc-dump cfile-dump"
for wrapper in ${wrappers}; do
  cat > ${BIN_DIR}/${wrapper} <<__EOT__
#!/bin/bash

export KUDU_HOME=\${KUDU_HOME:-/usr/lib/kudu}

${DO_EXEC}\${KUDU_HOME}/bin/$wrapper "\$@"
__EOT__
  chmod 755 ${BIN_DIR} ${BIN_DIR}/${wrapper}
done

install -d -m 0755 $CONF_DIR

install -d -m 0755 ${PREFIX}/var/run/kudu
install -d -m 0755 ${PREFIX}/var/log/kudu
install -d -m 0755 ${PREFIX}/var/lib/kudu

install -d -m 0755 ${PREFIX}/${SYSTEM_LIB_DIR}
install -d -m 0755 ${PREFIX}/${SYSTEM_INCLUDE_DIR}
cp `find ${BUILD_DIR}/client/usr/local/lib* -name \*.so\*` ${PREFIX}/${SYSTEM_LIB_DIR}/
cp -r ${BUILD_DIR}/client/usr/local/include/* ${PREFIX}/${SYSTEM_INCLUDE_DIR}/
cp -r ${BUILD_DIR}/client/usr/local/share ${PREFIX}/usr/share

cp -r ${BUILD_DIR}/www ${LIB_DIR}/

# Cloudera specific
install -d -m 0755 ${LIB_DIR}/cloudera
cp cloudera/cdh_version.properties ${LIB_DIR}/cloudera/

