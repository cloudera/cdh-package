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
set -x

usage() {
  echo "
usage: $0 <options>
  Required not-so-options:
     --build-dir=DIR             path to keytrustee-keyprovider dist.dir
     --prefix=PREFIX             path to install into

  Optional options:
     --lib-dir=DIR               path to install keytrustee-keyprovider home [/usr/share/keytrustee-keyprovider/lib]
     ... [ see source for more similar options ]
  "
  exit 1
}

OPTS=$(getopt \
  -n $0 \
  -o '' \
  -l 'prefix:' \
  -l 'lib-dir:' \
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
        --lib-dir)
        LIB_DIR=$2 ; shift 2
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

#Unfortunately at this point of time there is an inconsistency between the name
#of the tarball and the jar file.  The tar file has the name
#keytrustee-keyprovider* while the jar file is called keytrusteekp*

LIB_DIR=${LIB_DIR:-$PREFIX/usr/share/keytrustee-keyprovider/lib}

TARBALL=`ls build/keytrustee-keyprovider-${FULL_VERSION}.tar.gz`
DIRECTORY="build/keytrusteekp-${FULL_VERSION}"
pwd
(cd build && tar xvzf `basename ${TARBALL}`)

install -d -m 0755 ${LIB_DIR}
if [ ! -d $DIRECTORY ] ; then
    echo "Missing directory '$DIRECTORY' - most likely cause of this error is that the keytrustee pom.xml or cdh5.mk needs to be updated" >&2
    echo "Current directory is `pwd`" >&2
    ls -l build >&2
    exit 1
fi
mv ${DIRECTORY}/README.md `dirname ${LIB_DIR}`
mv build/keytrusteekp-*.jar ${LIB_DIR}
mv ${DIRECTORY}/lib/* ${LIB_DIR}/

# Cloudera specific
install -d -m 0755 $PREFIX/usr/share/keytrustee-keyprovider/cloudera
mv cloudera/cdh_version.properties $PREFIX/usr/share/keytrustee-keyprovider/cloudera/
