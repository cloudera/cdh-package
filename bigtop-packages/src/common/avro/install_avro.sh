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
     --build-dir=DIR             path to avro build dir
     --prefix=PREFIX             path to install into

  Optional options:
     --doc-dir=DIR               path to install docs into [/usr/share/doc/avro]
     --lib-dir=DIR               path to install avro home [/usr/lib/avro]
     --installed-lib-dir=DIR     path where lib-dir will end up on target system
     --bin-dir=DIR               path to install bins [/usr/bin]
     --examples-dir=DIR          path to install examples [doc-dir/examples]
     ... [ see source for more similar options ]
  "
  exit 1
}

OPTS=$(getopt \
  -n $0 \
  -o '' \
  -l 'prefix:' \
  -l 'doc-dir:' \
  -l 'lib-dir:' \
  -l 'installed-lib-dir:' \
  -l 'bin-dir:' \
  -l 'examples-dir:' \
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
        --doc-dir)
        DOC_DIR=$2 ; shift 2
        ;;
        --lib-dir)
        LIB_DIR=$2 ; shift 2
        ;;
        --installed-lib-dir)
        INSTALLED_LIB_DIR=$2 ; shift 2
        ;;
        --bin-dir)
        BIN_DIR=$2 ; shift 2
        ;;
        --examples-dir)
        EXAMPLES_DIR=$2 ; shift 2
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

LIB_DIR=${LIB_DIR:-/usr/lib/avro}
DOC_DIR=${DOC_DIR:-/usr/share/doc}

# Install Java libraries
mkdir -p ${PREFIX}/${LIB_DIR}
JARS=`ls dist/java/*.jar | grep ${FULL_VERSION}`
cp -p ${JARS} ${PREFIX}/${LIB_DIR}/
(cd ${PREFIX}/${LIB_DIR}; rm -f *-tests.jar *-javadoc.jar *-sources.jar)
cp lang/java/ipc/target/avro-ipc-${FULL_VERSION}-tests.jar ${PREFIX}/${LIB_DIR}/

# Apache Avro includes a -hadoop1 JAR and a versionless symlink to it for backward compatibility
# Only the -hadoop2 JAR is used in CDH, so we remove the -hadoop1 JAR and redirect the symlink
AVRO_MAPRED=avro-mapred-${FULL_VERSION}
rm -f ${PREFIX}/${LIB_DIR}/${AVRO_MAPRED}.jar ${PREFIX}/${LIB_DIR}/${AVRO_MAPRED}-hadoop1.jar
ln -s ${AVRO_MAPRED}-hadoop2.jar ${PREFIX}/${LIB_DIR}/${AVRO_MAPRED}.jar

# Install versionless symlinks
versions='s#-[0-9.]\+-cdh[0-9\-\.]*[0-9]\(-beta-[0-9]\+\)\?\(-SNAPSHOT\)\?##'
for jar in `ls ${PREFIX}/${LIB_DIR}/*.jar`; do
    base=`basename $jar`
    (cd ${PREFIX}/${LIB_DIR} && ln -s $base `echo $base | sed -e $versions`)
done

# Install documentation
install -d ${PREFIX}/${DOC_DIR}
cp -r build/avro-doc-* ${PREFIX}/${DOC_DIR}

# Install CLI Tools
install -d -m 0755 ${PREFIX}/usr/bin
cat > ${PREFIX}/usr/bin/avro-tools <<EOF
#!/bin/bash

# Autodetect JAVA_HOME if not defined
. /usr/lib/bigtop-utils/bigtop-detect-javahome

\${JAVA_HOME}/bin/java -jar ${LIB_DIR}/avro-tools.jar \$@
EOF
chmod 0755 ${PREFIX}/usr/bin/avro-tools

cp LICENSE.txt NOTICE.txt ${PREFIX}/${LIB_DIR}/

