#!/bin/sh

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
     --build-dir=DIR             path to hive dist.dir
     --prefix=PREFIX             path to install into

  Optional options:
     --doc-dir=DIR               path to install docs into [/usr/share/doc/hive]
     --lib-dir=DIR               path to install hive home [/usr/lib/hive]
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

LIB_DIR=${LIB_DIR:-$PREFIX/usr/lib/hadoop}
install -d -m 0755 $LIB_DIR/lib
for library in \
        access-tests/target/access-tests access-core/target/access-core \
        access-provider/access-provider-file/target/access-provider-file; do
    cp $library*.jar $LIB_DIR/lib/
done

for plugin in hive; do
    PLUGIN_LIB_JAR=access-binding/access-binding-${plugin}/target/access-binding-${plugin}-*.jar
    PLUGIN_LIB_DIR=${HIVE_LIB_DIR:-$PREFIX/usr/lib/${plugin}/lib}
    install -d -m 0755 $PLUGIN_LIB_DIR
    cp $PLUGIN_LIB_JAR $PLUGIN_LIB_DIR/
done

# Cloudera specific
install -d -m 0755 $LIB_DIR/access/cloudera
cp cloudera/cdh_version.properties $LIB_DIR/access/cloudera/

