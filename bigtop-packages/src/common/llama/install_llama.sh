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
     --build-dir=DIR             path to llama tarball with binaries
     --prefix=PREFIX             path to install into

  Optional options:
     --lib-dir=DIR               path to install llama jar files
     --conf-dir=DIR              path to install default configuration files
     --extra-dir=DIR             path to additional source files
     --doc-dir=DIR               path to install docs into [/usr/share/doc/llama]
     ... [ see source for more similar options ]
  "
  exit 1
}

OPTS=$(getopt \
  -n $0 \
  -o '' \
  -l 'prefix:' \
  -l 'lib-dir:' \
  -l 'conf-dir:' \
  -l 'extra-dir:' \
  -l 'doc-dir:' \
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
        --conf-dir)
        CONF_DIR=$2 ; shift 2
        ;;
        --extra-dir)
        EXTRA_DIR=$2 ; shift 2
        ;;
        --doc-dir)
        DOC_DIR=$2 ; shift 2
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

DOC_DIR=${DOC_DIR:-/usr/share/doc/llama}
LIB_DIR=${LIB_DIR:-/usr/lib/llama}
CONF_DIR=${CONF_DIR:-/etc/llama/conf.dist}
EXTRA_DIR=${EXTRA_DIR:-./}

DIST_DIR=${BUILD_DIR}/llama-*/llama-dist/target/llama-*/llama-*/
YARN_DIR=${PREFIX}/usr/lib/hadoop-yarn

install -d -m 0755 ${PREFIX}/${LIB_DIR}
cp -r ${DIST_DIR}/libexec ${PREFIX}/${LIB_DIR}/
cp -r ${DIST_DIR}/lib ${PREFIX}/${LIB_DIR}/
cp -r ${DIST_DIR}/bin ${PREFIX}/${LIB_DIR}/

mv ${PREFIX}/${LIB_DIR}/lib/llama-*.jar ${PREFIX}/${LIB_DIR}/

install -d -m 0755 ${PREFIX}/${CONF_DIR}
cp -r ${DIST_DIR}/conf/* ${PREFIX}/${CONF_DIR}
install -d -m 0755 ${PREFIX}/etc/default
cp ${EXTRA_DIR}/llama.default ${PREFIX}/etc/default/llama

install -d -m 0755 ${PREFIX}/usr/bin
for wrapper in llama llamaadmin; do
cat > ${PREFIX}/usr/bin/${wrapper} <<EOF
#!/bin/bash

# Autodetect JAVA_HOME if not defined
. /usr/lib/bigtop-utils/bigtop-detect-javahome

BIGTOP_DEFAULTS_DIR=\${BIGTOP_DEFAULTS_DIR-/etc/default}
[ -n "\${BIGTOP_DEFAULTS_DIR}" -a -r \${BIGTOP_DEFAULTS_DIR}/llama ] && . \${BIGTOP_DEFAULTS_DIR}/llama

export HADOOP_CLASSPATH=\$(JARS=(${LIB_DIR}/*.jar ${LIB_DIR}/lib/*.jar); IFS=:; echo "\${JARS[*]}:\${HADOOP_CLASSPATH}")
export HADOOP_CLASSPATH=/etc/hadoop/conf:\${HADOOP_CLASSPATH}

export HADOOP_LIBEXEC_DIR=/usr/lib/hadoop/libexec
export HADOOP_HOME=/usr/lib/hadoop

exec ${LIB_DIR}/bin/${wrapper} "\$@"
EOF
done

install -d -m 0755 ${PREFIX}/${DOC_DIR}
cp -r ${BUILD_DIR}/target/site/* ${PREFIX}/${DOC_DIR}/

install -d -m 0755 ${PREFIX}/var/run/llama
install -d -m 0755 ${PREFIX}/var/log/llama
install -d -m 0755 ${PREFIX}/var/lib/llama

cp ${BUILD_DIR}/LICENSE.txt ${PREFIX}/${LIB_DIR}/

# Cloudera specific
install -d -m 0755 ${PREFIX}/${LIB_DIR}/cloudera
cp cloudera/cdh_version.properties ${PREFIX}/${LIB_DIR}/cloudera/

internal_versionless_symlinks ${PREFIX}/${LIB_DIR}/llama*.jar

external_versionless_symlinks 'llama' ${PREFIX}/${LIB_DIR}/lib

