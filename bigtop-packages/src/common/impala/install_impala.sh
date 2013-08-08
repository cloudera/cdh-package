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
     --build-dir=DIR             path to hive/build/dist
     --prefix=PREFIX             path to install into
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
LIB_DIR=${LIB_DIR:-$PREFIX/usr/lib/impala}
BIN_DIR=${BIN_DIR:-$PREFIX/usr/bin}
DOC_DIR=${DOC_DIR:-$PREFIX/usr/share/doc/impala}
MAN_DIR=${MAN_DIR:-$PREFIX/usr/man}
CONF_DIR=${CONF_DIR:-$PREFIX/etc/impala/conf.dist}

# install java bits
install -d -m 0755 ${LIB_DIR}
# cp fe/target/*.jar ${LIB_DIR}

# install daemons
install -d -m 0755 ${LIB_DIR}/sbin-retail
cp be/build/release/service/* ${LIB_DIR}/sbin-retail
cp be/build/release/statestore/statestored ${LIB_DIR}/sbin-retail/statestored
rm ${LIB_DIR}/sbin-retail/*.a

# install debug bits
install -d -m 0755 ${LIB_DIR}/sbin-debug
cp be/build/debug/service/* ${LIB_DIR}/sbin-debug
cp be/build/debug/statestore/statestored ${LIB_DIR}/sbin-debug/statestored
rm ${LIB_DIR}/sbin-debug/*.a

# install scripts
install -d -m 0755 ${LIB_DIR}/bin
# cp bin/* ${LIB_DIR}/bin

# install llvm artifacts
install -d -m 0755 ${LIB_DIR}/llvm-ir
cp llvm-ir/* ${LIB_DIR}/llvm-ir

# install web document root
install -d -m 0755 ${LIB_DIR}/www
cp -fr www/* ${LIB_DIR}/www/

# install dependencies
install -d -m 0755 ${LIB_DIR}/lib
cp thirdparty/hadoop-*/lib/native/libhdfs.so* ${LIB_DIR}/lib
cp thirdparty/hadoop-*/lib/native/libhadoop.so* ${LIB_DIR}/lib
cp -fr fe/target/dependency/* ${LIB_DIR}/lib/
cp fe/target/impala-frontend-*-SNAPSHOT.jar ${LIB_DIR}/lib

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
IMPALA_STATE_STORE_HOST=127.0.0.1
IMPALA_STATE_STORE_PORT=24000
IMPALA_BACKEND_PORT=22000
IMPALA_LOG_DIR=/var/log/impala

IMPALA_STATE_STORE_ARGS=" -log_dir=\${IMPALA_LOG_DIR} -state_store_port=\${IMPALA_STATE_STORE_PORT}"
IMPALA_SERVER_ARGS=" \\
    -log_dir=\${IMPALA_LOG_DIR} \\
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
for wrapper in impalad statestored ; do
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
  chmod 755 ${BIN_DIR} ${BIN_DIR}/${wrapper}
done

install -d -m 0755 $CONF_DIR

# Replace bundled libraries with symlinks to packaged dependencies
export DEPENDENCY_DIR=${PREFIX}/usr/lib/impala/lib
function symlink_lib() {
    file=$1
    dir=$2
    rm $file
    ln -s ../../$dir/`basename $file` $DEPENDENCY_DIR
}
for file in $DEPENDENCY_DIR/hadoop*cdh*.jar; do symlink_lib $file hadoop; done
for file in $DEPENDENCY_DIR/hbase*cdh*.jar; do symlink_lib $file hbase; done
for file in $DEPENDENCY_DIR/hive*cdh*.jar; do symlink_lib $file hive/lib; done
for file in $DEPENDENCY_DIR/zookeeper*cdh*.jar; do symlink_lib $file zookeeper; done
for file in $DEPENDENCY_DIR/libh*.so*; do symlink_lib $file hadoop/lib/native; done

# Cloudera specific
install -d -m 0755 $LIB_DIR/cloudera
cp cloudera/cdh_version.properties $LIB_DIR/cloudera/

install -d -m 0755 $PREFIX/var/run/impala
install -d -m 0755 $PREFIX/var/log/impala
install -d -m 0755 $PREFIX/var/lib/impala
