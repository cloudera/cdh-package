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
  -l 'sbin-dir:' \
  -l 'doc-dir:' \
  -l 'man-dir:' \
  -l 'conf-dir:' \
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
        --sbin-dir)
        SBIN_DIR=$2 ; shift 2
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

ETC_DIR=${ETC_DIR:-$PREFIX/etc}
LIB_DIR=${LIB_DIR:-$PREFIX/usr/lib/kudu}
BIN_DIR=${BIN_DIR:-$PREFIX/usr/bin}
SBIN_DIR=${SBIN_DIR:-$PREFIX/usr/sbin}
DOC_DIR=${DOC_DIR:-$PREFIX/usr/share/doc/kudu}
MAN_DIR=${MAN_DIR:-$PREFIX/usr/man}
CONF_DIR=${CONF_DIR:-$PREFIX/etc/kudu/conf.dist}
SYSTEM_INCLUDE_DIR=${SYSTEM_INCLUDE_DIR:-/usr/include}
SYSTEM_LIB_DIR=${SYSTEM_LIB_DIR:-/usr/lib}

install -d -m 0755 ${LIB_DIR}

bin_executables="cfile-dump \
                 kudu-admin \
                 kudu-fs_dump \
                 kudu-fs_list \
                 kudu-ksck \
                 kudu-pbc-dump \
                 kudu-ts-cli \
                 log-dump"
install -d -m 0755 ${LIB_DIR}/bin-release
install -d -m 0755 ${LIB_DIR}/bin-debug
for executable in ${bin_executables}; do
    cp ${BUILD_DIR}/build/release/bin/${executable} ${LIB_DIR}/bin-release/
    cp ${BUILD_DIR}/build/fastdebug/bin/${executable} ${LIB_DIR}/bin-debug/
done

sbin_executables="kudu-master \
                  kudu-tserver"
install -d -m 0755 ${LIB_DIR}/sbin-release
install -d -m 0755 ${LIB_DIR}/sbin-debug
for executable in ${sbin_executables}; do
    cp ${BUILD_DIR}/build/release/bin/${executable} ${LIB_DIR}/sbin-release/
    cp ${BUILD_DIR}/build/fastdebug/bin/${executable} ${LIB_DIR}/sbin-debug/
done

# now, create the defaults files
install -d -m 0755 ${ETC_DIR}/default

cat > ${ETC_DIR}/default/kudu-master <<__EOT__
export FLAGS_log_dir=/var/log/kudu
export FLAGS_rpc_bind_addresses=0.0.0.0:7051
__EOT__
chmod 0644 ${ETC_DIR}/default/kudu-master

cat > ${ETC_DIR}/default/kudu-tserver <<__EOT__
export FLAGS_log_dir=/var/log/kudu
export FLAGS_rpc_bind_addresses=0.0.0.0:7050
__EOT__
chmod 0644 ${ETC_DIR}/default/kudu-tserver

# and the gflagfiles
install -d -m 0755 $CONF_DIR

cat > ${CONF_DIR}/master.gflagfile <<__EOT__
# Do not modify these two lines. If you wish to change these variables,
# modify them in /etc/default/kudu-master.
--fromenv=rpc_bind_addresses
--fromenv=log_dir

--fs_wal_dir=/var/lib/kudu/master
--fs_data_dirs=/var/lib/kudu/master
__EOT__
chmod 0644 ${CONF_DIR}/master.gflagfile

cat > ${CONF_DIR}/tserver.gflagfile <<__EOT__
# Do not modify these two lines. If you wish to change these variables,
# modify them in /etc/default/kudu-tserver.
--fromenv=rpc_bind_addresses
--fromenv=log_dir

--fs_wal_dir=/var/lib/kudu/tserver
--fs_data_dirs=/var/lib/kudu/tserver
__EOT__
chmod 0644 ${CONF_DIR}/tserver.gflagfile

# create wrapper scripts in /usr/bin for user-facing executables
install -d -m 0755 ${BIN_DIR}
DO_EXEC="exec "
for wrapper in ${bin_executables}; do
  cat > ${BIN_DIR}/${wrapper} <<__EOT__
#!/bin/bash

export KUDU_HOME=\${KUDU_HOME:-/usr/lib/kudu}

${DO_EXEC}\${KUDU_HOME}/bin/$wrapper "\$@"
__EOT__
  chmod 755 ${BIN_DIR}/${wrapper}
done

# and wrapper scripts in /usr/sbin
install -d -m 0755 ${SBIN_DIR}
for wrapper in ${sbin_executables}; do
  cat > ${SBIN_DIR}/${wrapper} <<__EOT__
#!/bin/bash

export KUDU_HOME=\${KUDU_HOME:-/usr/lib/kudu}

${DO_EXEC}\${KUDU_HOME}/sbin/$wrapper "\$@"
__EOT__
  chmod 755 ${SBIN_DIR}/${wrapper}
done

install -d -m 0755 ${PREFIX}/var/run/kudu
install -d -m 0755 ${PREFIX}/var/log/kudu
install -d -m 0755 ${PREFIX}/var/lib/kudu

install -d -m 0755 ${PREFIX}/${SYSTEM_LIB_DIR}
install -d -m 0755 ${PREFIX}/${SYSTEM_LIB_DIR}/debug
install -d -m 0755 ${PREFIX}/${SYSTEM_INCLUDE_DIR}

# Copy in the client libraries and SONAME symlinks. The release file set is
# copied in directly, while the debug set is placed in a subdirectory.
for lib in `find ${BUILD_DIR}/build/release/client/usr/local/lib* -name \*.so\*`; do
  cp -d $lib ${PREFIX}/${SYSTEM_LIB_DIR}
done
for lib in `find ${BUILD_DIR}/build/fastdebug/client/usr/local/lib* -name \*.so\*`; do
  cp -d $lib ${PREFIX}/${SYSTEM_LIB_DIR}/debug
done

# Doesn't matter whether we use release or fastdebug here; we're not copying binaries.
cp -r ${BUILD_DIR}/build/release/client/usr/local/include/* ${PREFIX}/${SYSTEM_INCLUDE_DIR}/
cp -r ${BUILD_DIR}/build/release/client/usr/local/share ${PREFIX}/usr/share

cp -r ${BUILD_DIR}/www ${LIB_DIR}/

# Cloudera specific
install -d -m 0755 ${LIB_DIR}/cloudera
cp cloudera/cdh_version.properties ${LIB_DIR}/cloudera/

# Copy the license files, folding the thirdparty licenses into the main file.
install -d -m 0755 ${PREFIX}/${DOC_DIR}
cp ${BUILD_DIR}/DISCLAIMER ${PREFIX}/${DOC_DIR}
cp ${BUILD_DIR}/NOTICE.txt ${PREFIX}/${DOC_DIR}
cp ${BUILD_DIR}/LICENSE.txt ${PREFIX}/${DOC_DIR}
echo >> ${PREFIX}/${DOC_DIR}/LICENSE.txt
echo "Third-party LICENSE.txt follows" >> ${PREFIX}/${DOC_DIR}/LICENSE.txt
echo "===============================" >> ${PREFIX}/${DOC_DIR}/LICENSE.txt
cat ${BUILD_DIR}/thirdparty/LICENSE.txt >> ${PREFIX}/${DOC_DIR}/LICENSE.txt
