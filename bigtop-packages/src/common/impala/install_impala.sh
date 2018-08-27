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
trap 'echo Error in $0 at line $LINENO: $(cd "'$PWD'" && awk "NR == $LINENO" $0)' ERR

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
LIB_DIR=${LIB_DIR:-$PREFIX/usr/lib/impala}
BIN_DIR=${BIN_DIR:-$PREFIX/usr/bin}
DOC_DIR=${DOC_DIR:-$PREFIX/usr/share/doc/impala}
MAN_DIR=${MAN_DIR:-$PREFIX/usr/man}
CONF_DIR=${CONF_DIR:-$PREFIX/etc/impala/conf.dist}
NATIVE_LIB_DIR=${NATIVE_LIB_DIR:-lib}
SYSTEM_INCLUDE_DIR=${SYSTEM_INCLUDE_DIR:-/usr/include}
SYSTEM_LIB_DIR=${SYSTEM_LIB_DIR:-/usr/lib}

# install java bits
install -d -m 0755 ${LIB_DIR}
# cp fe/target/*.jar ${LIB_DIR}

# install daemons
install -d -m 0755 ${LIB_DIR}/sbin-retail
cp be/build/release/service/* ${LIB_DIR}/sbin-retail
ln -s impalad ${LIB_DIR}/sbin-retail/statestored
ln -s impalad ${LIB_DIR}/sbin-retail/catalogd
rm ${LIB_DIR}/sbin-retail/*.a

# install debug bits
install -d -m 0755 ${LIB_DIR}/sbin-debug
cp be/build/debug/service/* ${LIB_DIR}/sbin-debug
ln -s impalad ${LIB_DIR}/sbin-debug/statestored
ln -s impalad ${LIB_DIR}/sbin-debug/catalogd
rm ${LIB_DIR}/sbin-debug/*.a

# install scripts
install -d -m 0755 ${LIB_DIR}/bin
cp bin/collect_minidumps.py bin/diagnostics/*.py bin/diagnostics/*.sh  ${LIB_DIR}/bin
# cp bin/* ${LIB_DIR}/bin

# install web document root
install -d -m 0755 ${LIB_DIR}/www
cp -fr www/* ${LIB_DIR}/www/

# install dependencies
install -d -m 0755 ${LIB_DIR}/lib
cp -fr fe/target/dependency/* ${LIB_DIR}/lib/
cp fe/target/impala-frontend-*-SNAPSHOT.jar ${LIB_DIR}/lib

# Install required 3rd-party dependencies provided by the toolchain. Only libstdc++,
# libgcc, the Kudu client and libssl should be needed. Everything else is statically linked.
IMPALA_TOOLCHAIN=toolchain
find ${IMPALA_TOOLCHAIN} -name "libstdc++*.so.*" -and -not -name "*-gdb.py" -exec cp -L {} ${LIB_DIR}/lib \;
find ${IMPALA_TOOLCHAIN} -name "libgcc*.so.*" -and -not -name "*-gdb.py" -exec cp -L {} ${LIB_DIR}/lib \;
# Don't pick up the debug version of the client. It's in a "debug" folder.
find ${IMPALA_TOOLCHAIN} -name "libkudu_client.so.*" -not -path "*debug*" -exec cp -L {} ${LIB_DIR}/lib \;

# Include libssl.so and libcrypto.so as part of the package which may be used on
# legacy platforms which don't have OpenSSL 1.0.0 installed by default. We include
# them even on platforms which have OpenSSL 1.0.0 in case the user wants to override
# the behavior at runtime with env variable USE_PACKAGE_OPENSSL.
mkdir ${LIB_DIR}/lib/openssl
find ${IMPALA_TOOLCHAIN} -name "libssl.so*" -exec cp -L {} ${LIB_DIR}/lib/openssl \;
find ${IMPALA_TOOLCHAIN} -name "libcrypto.so*" -exec cp -L {} ${LIB_DIR}/lib/openssl \;

# Impala builds against libssl.so and libcrypto.so in the toolchain if the platform doesn't have
# OpenSSL 1.0.0. The env variable USE_PACKAGE_OPENSSL determines at run time whether to add OpenSSL
# library in the package to LD_LIBRARY_PATH. This code below determines USE_PACKAGE_OPENSSL_DEFAULT
# at build time, and it will be forwarded into the impalad shell script wrapper. In practice,
# USE_PACKAGE_OPENSSL_DEFAULT will be 0 except for RH5 and SLES11.
USE_PACKAGE_OPENSSL_DEFAULT="0"
read OPENSSL_MAJ_VER OPENSSL_MIN_VER OPENSSL_PATCH_VER <<< `openssl version |  sed -r 's/^OpenSSL ([0-9]+)\.([0-9]+)\.([0-9a-z]+).*/\1 \2 \3/'`
if [[ ${OPENSSL_MAJ_VER} = "0" ]]; then
    export USE_PACKAGE_OPENSSL_DEFAULT="1"
fi

if [ -d thirdparty ]; then
  cp thirdparty/hadoop-*/lib/native/libhdfs.so* ${LIB_DIR}/lib
  cp thirdparty/hadoop-*/lib/native/libhadoop.so* ${LIB_DIR}/lib
else
  find ${IMPALA_TOOLCHAIN} -name "libhdfs.so*" -and -not -name "*-gdb.py" -exec cp -L {} ${LIB_DIR}/lib \;
  find ${IMPALA_TOOLCHAIN} -name "libhadoop.so*" -and -not -name "*-gdb.py" -exec cp -L {} ${LIB_DIR}/lib \;
fi

# Replace bundled libraries with symlinks to packaged dependencies
export DEPENDENCY_DIR=${PREFIX}/usr/lib/impala/lib
function symlink_lib() {
    file=$1
    dir=$2
    rm $file
    base=`basename $file`
    versionless=${base/-[0-9].*/.jar}
    ln -s ../../$dir/`basename $versionless` $DEPENDENCY_DIR/
}
# Remove MR1 Hive shim
rm -f $DEPENDENCY_DIR/hive-shims-0.23*.jar $DEPENDENCY_DIR/hadoop-core*.jar;
for file in $DEPENDENCY_DIR/libhdfs*.so*; do symlink_lib $file ../${NATIVE_LIB_DIR}; done
for file in $DEPENDENCY_DIR/libhadoop*.so*; do symlink_lib $file hadoop/lib/native; done

external_versionless_symlinks 'impala' ${LIB_DIR}/lib

# install Impala shell
install -d -m 0755 ${LIB_DIR}-shell
tar --strip-components 2 -C ${LIB_DIR}-shell -xzf shell/build/impala*.tar.gz
install -d -m 0755 ${BIN_DIR}
mv ${LIB_DIR}-shell/impala-shell ${BIN_DIR}
sed -i -e '/^SCRIPT_DIR=/s#^.*$#SCRIPT_DIR=/usr/lib/impala-shell#' ${BIN_DIR}/impala-shell

IMPALA_DEPS=`cd ${LIB_DIR}/lib/ ; ls * | sed -e 's#^#${IMPALA_HOME}/lib/#' | tr '\012' ':'`

# Make sure that Thrift libs get onto CLASSPATH first; can remove once Impala is upgraded to Hive 10
THRIFT_DEPS=`cd ${LIB_DIR}/lib/ ; ls libthrift* | sed -e 's#^#${IMPALA_HOME}/lib/#' | tr '\012' ':'`

# now, create a default file
install -d -m 0755 ${ETC_DIR}/default
cat > ${ETC_DIR}/default/impala <<__EOT__
IMPALA_CATALOG_SERVICE_HOST=127.0.0.1
IMPALA_STATE_STORE_HOST=127.0.0.1
IMPALA_STATE_STORE_PORT=24000
IMPALA_BACKEND_PORT=22000
IMPALA_LOG_DIR=/var/log/impala

IMPALA_CATALOG_ARGS=" -log_dir=\${IMPALA_LOG_DIR} "
IMPALA_STATE_STORE_ARGS=" -log_dir=\${IMPALA_LOG_DIR} -state_store_port=\${IMPALA_STATE_STORE_PORT}"
IMPALA_SERVER_ARGS=" \\
    -log_dir=\${IMPALA_LOG_DIR} \\
    -catalog_service_host=\${IMPALA_CATALOG_SERVICE_HOST} \\
    -state_store_port=\${IMPALA_STATE_STORE_PORT} \\
    -use_statestore \\
    -state_store_host=\${IMPALA_STATE_STORE_HOST} \\
    -be_port=\${IMPALA_BACKEND_PORT}"

ENABLE_CORE_DUMPS=false

# LIBHDFS_OPTS=-Djava.library.path=/usr/lib/impala/lib
# MYSQL_CONNECTOR_JAR=/usr/share/java/mysql-connector-java.jar
# IMPALA_BIN=/usr/lib/impala/sbin
# IMPALA_HOME=/usr/lib/impala
# HIVE_HOME=/usr/lib/hive
# HBASE_HOME=/usr/lib/hbase
# IMPALA_CONF_DIR=/etc/impala/conf
# HADOOP_CONF_DIR=/etc/impala/conf
# HIVE_CONF_DIR=/etc/impala/conf
# HBASE_CONF_DIR=/etc/impala/conf

__EOT__
chmod 0644 ${ETC_DIR}/default/impala

# finally install wrapper scripts
install -d -m 0755 ${BIN_DIR}
DO_EXEC="exec "
for wrapper in impalad statestored catalogd ; do
  cat > ${BIN_DIR}/${wrapper} <<__EOT__
#!/bin/bash

export IMPALA_BIN=\${IMPALA_BIN:-/usr/lib/impala/sbin}
export IMPALA_HOME=\${IMPALA_HOME:-/usr/lib/impala}
export HIVE_HOME=\${HIVE_HOME:-/usr/lib/hive}
export HBASE_HOME=\${HBASE_HOME:-/usr/lib/hbase}
export IMPALA_CONF_DIR=\${IMPALA_CONF_DIR:-/etc/impala/conf}
export HADOOP_CONF_DIR=\${HADOOP_CONF_DIR:-/etc/impala/conf}
export HIVE_CONF_DIR=\${HIVE_CONF_DIR:-/etc/impala/conf}
export HBASE_CONF_DIR=\${HBASE_CONF_DIR:-/etc/impala/conf}
export LIBHDFS_OPTS=\${LIBHDFS_OPTS:--Djava.library.path=/usr/lib/impala/lib}
export MYSQL_CONNECTOR_JAR=\${MYSQL_CONNECTOR_JAR:-/usr/share/java/mysql-connector-java.jar}

if [ "\$ENABLE_CORE_DUMPS" == "true" ] ; then
    ulimit -c unlimited
elif [ -z "\$ENABLE_CORE_DUMPS" -o "\$ENABLE_CORE_DUMPS" == "false" ] ; then
    ulimit -c 0
else
    echo 'WARNING: \$ENABLE_CORE_DUMPS must be either "true" or "false"'
fi

# Autodetect JAVA_HOME if not defined
. /usr/lib/bigtop-utils/bigtop-detect-javahome

# ensure that java has already been found
if [ -z "\${JAVA_HOME}" ]; then
  echo "Unable to find Java. JAVA_HOME should be set in /etc/default/bigtop-utils"
  exit 1
fi

# Autodetect location of native java libraries
for library in libjvm.so libjsig.so libjava.so; do
    library_file=\`find \${JAVA_HOME}/ -name \$library | head -1\`
    if [ -n "\$library_file" ] ; then
        library_dir=\`dirname \$library_file\`
        export LD_LIBRARY_PATH=\$library_dir:\${LD_LIBRARY_PATH}
    fi
done
export LD_LIBRARY_PATH="\${IMPALA_HOME}/lib:\${IMPALA_BIN}:\${LD_LIBRARY_PATH}"

# USE_PACKAGE_OPENSSL can be overridden by the user in CM.
if [ -z "\${USE_PACKAGE_OPENSSL}" ]; then
    export USE_PACKAGE_OPENSSL="${USE_PACKAGE_OPENSSL_DEFAULT}"
fi
if [ \${USE_PACKAGE_OPENSSL} = "1" ]; then
    export LD_LIBRARY_PATH="\${IMPALA_HOME}/lib/openssl:\${LD_LIBRARY_PATH}"
fi

export CLASSPATH="$THRIFT_DEPS:$IMPALA_DEPS:\${CLASSPATH}"
export CLASSPATH="\${IMPALA_CONF_DIR}:\${HADOOP_CONF_DIR}:\${HIVE_CONF_DIR}:\${HBASE_CONF_DIR}:\${CLASSPATH}"
export CLASSPATH="\${MYSQL_CONNECTOR_JAR}:\${CLASSPATH}"
for JAR_FILE in /var/lib/impala/*.jar; do
    export CLASSPATH="\${JAR_FILE}:\${CLASSPATH}"
done
if [ -n "\${AUX_CLASSPATH}" ]; then
    export CLASSPATH="\${AUX_CLASSPATH}:\${CLASSPATH}"
fi

# Add non-standard kinit location to PATH
if [ -d /usr/kerberos/bin ]; then
  export PATH=/usr/kerberos/bin:\${PATH}
fi

${DO_EXEC}\${IMPALA_BIN}/$wrapper "\$@"
__EOT__
  export IMPALA_BIN=\${IMPALA_BIN:-/usr/lib/impala/sbin}
  chmod 755 ${BIN_DIR} ${BIN_DIR}/${wrapper}
done

# install the minidump collection script
cat > ${BIN_DIR}/impala-collect-minidumps <<__EOT__
#!/bin/bash
export LIB_DIR=\${LIB_DIR:-/usr/lib}
${DO_EXEC}\${LIB_DIR}/impala/bin/collect_minidumps.py "\$@"
__EOT__
chmod 755 ${BIN_DIR} ${BIN_DIR}/impala-collect-minidumps

# Install collect_diagnostics.py
cat > ${BIN_DIR}/impala-collect-diagnostics <<__EOT__
#!/bin/bash
export LIB_DIR=\${LIB_DIR:-/usr/lib}
${DO_EXEC}\${LIB_DIR}/impala/bin/collect_diagnostics.py "\$@"
__EOT__
chmod 755 ${BIN_DIR} ${BIN_DIR}/impala-collect-diagnostics

install -d -m 0755 $CONF_DIR

install -d -m 0755 $PREFIX/var/run/impala
install -d -m 0755 $PREFIX/var/log/impala
install -d -m 0755 $PREFIX/var/lib/impala

install -d -m 0755 ${PREFIX}/${SYSTEM_INCLUDE_DIR}/impala_udf
cp ./be/src/udf/*.h ${PREFIX}/${SYSTEM_INCLUDE_DIR}/impala_udf
rm ${PREFIX}/${SYSTEM_INCLUDE_DIR}/impala_udf/udf-internal.h
for header_file in ${PREFIX}/${SYSTEM_INCLUDE_DIR}/impala_udf/*.h; do
    sed -i -e 's@#include "udf/\(.*\.h\)"@#include <impala_udf/\1>@' ${header_file}
done
install -d -m 0755 ${PREFIX}/${SYSTEM_LIB_DIR}
cp be/build/release/udf/libImpalaUdf.a ${PREFIX}/${SYSTEM_LIB_DIR}/libImpalaUdf-retail.a
cp be/build/debug/udf/libImpalaUdf.a ${PREFIX}/${SYSTEM_LIB_DIR}/libImpalaUdf-debug.a

if [ -d thirdparty ]; then
  NOTICES_SOURCE=thirdparty
else
  NOTICES_SOURCE=${IMPALA_TOOLCHAIN}
fi
NOTICES=`find ${NOTICES_SOURCE} -name 'LICENSE*' -o -name 'NOTICE*' | grep -v llama | grep -v hive | grep -v hbase |  grep -v hadoop`
for notice in ${NOTICES}; do
    dir=`dirname ${LIB_DIR}/${notice}`
    install -d -m 0755 ${dir}
    cp ${notice} ${dir}/
done

# Cloudera specific
install -d -m 0755 $LIB_DIR/cloudera
cp cloudera/cdh_version.properties $LIB_DIR/cloudera/
