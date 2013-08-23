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

set -ex

usage() {
  echo "
usage: $0 <options>
  Required not-so-options:
     --build-dir=DIR             path to flumedist.dir
     --prefix=PREFIX             path to install into

  Optional options:
     --doc-dir=DIR               path to install docs into [/usr/share/doc/flume]
     --flume-dir=DIR             path to install flume home [/usr/lib/flume]
     --installed-lib-dir=DIR     path where lib-dir will end up on target system
     ... [ see source for more similar options ]
  "
  exit 1
}

OPTS=$(getopt \
  -n $0 \
  -o '' \
  -l 'prefix:' \
  -l 'doc-dir:' \
  -l 'doc-dir-prefix:' \
  -l 'flume-dir:' \
  -l 'installed-lib-dir:' \
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
        --doc-dir-prefix)
        DOC_DIR_PREFIX=$2 ; shift 2
        ;;
        --flume-dir)
        FLUME_DIR=$2 ; shift 2
        ;;
        --installed-lib-dir)
        INSTALLED_LIB_DIR=$2 ; shift 2
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

LIB_DIR=${LIB_DIR:-/usr/lib/search}
MAN_DIR=${MAN_DIR:-/usr/share/man/man1}
DOC_DIR=${DOC_DIR:-/usr/share/doc/search}
DOC_DIR_PREFIX=${DOC_DIR_PREFIX:-$PREFIX}
FLUME_DIR=${FLUME_DIR:-/usr/lib/flume-ng}
# FIXME: once solr-mr and core indexer go upstream we need to rationalize this
SOLR_MR_DIR=${SOLR_MR_DIR:-/usr/lib/solr/contrib/mr}
CONF_DIR=/etc/flume-ng/
CONF_DIST_DIR=/etc/flume-ng/conf.dist/
ETC_DIR=${ETC_DIR:-/etc/flume-ng}

# Untar the build tar
(cd ${BUILD_DIR}/search-dist/target ; tar --strip-components=1 -xzf cloudera-search*.tar.gz)

# Create the search package
install -d -m 0755 ${PREFIX}/${LIB_DIR}
cp -r ${BUILD_DIR}/search-dist/target/dist/* ${PREFIX}/${LIB_DIR}

# Plugin jars
install -d -m 0755 ${PREFIX}/${FLUME_DIR}/lib
mv -f ${PREFIX}/${LIB_DIR}/search-contrib* ${PREFIX}/${FLUME_DIR}/lib

# FIXME: A really ugly workaround to make package work against CDH4.3
#        and CDH4.4 at the same time
(cd ${BUILD_DIR}/search-dist/flume-ng-solr-sink-dist/target/lib/;
  rm -f avro-*.jar avro-ipc-*.jar commons-cli-*.jar commons-compress-*.jar \
        commons-io-*.jar commons-lang-*.jar gson-*.jar guava-*.jar         \
        jsr305-*.jar libthrift-*.jar log4j-*.jar netty-*.Final.jar         \
        paranamer-*.jar servlet-api-*.jar slf4j-api-*.jar                  \
        slf4j-log4j12-*.jar snappy-java-*.jar velocity-*.jar xz-1.0.jar    \
        zookeeper-*.jar flume-ng-configuration-*.jar flume-ng-core-*.jar   \
        flume-ng-sdk-*.jar httpcore-*.jar jackson-core-asl-*.jar           \
        jackson-mapper-asl-*.jar jetty-*.jar jetty-util-*.jar              \
        joda-time-*.jar vorbis-java-core-*-tests.jar hadoop*.jar           \
        commons-collections*.jar commons-configuration*.jar jsp-api*.jar   \
        junit-*.jar mockito-all-*.jar protobuf-*.jar httpclient*.jar       \
        cdk-morphlines-all*.pom
  for i in commons-logging*.jar commons-codec* jackson-core* flume-ng-morphline-solr-sink* ; do
    mv $i search-$i
  done
)
cp ${BUILD_DIR}/search-dist/flume-ng-solr-sink-dist/target/lib/* ${PREFIX}/${FLUME_DIR}/lib

# FIXME: we have to replace a real solr-solrj.jar with a shaded copy
rm -f ${PREFIX}/${FLUME_DIR}/lib/solr-solrj*.jar
cp ${PREFIX}/${LIB_DIR}/solr-solrj-dist*.jar ${PREFIX}/${FLUME_DIR}/lib/

# FIXME: once solr-mr
install -d -m 0755 ${PREFIX}/${SOLR_MR_DIR}
mv -f ${PREFIX}/${LIB_DIR}/search-mr*.jar ${PREFIX}/${SOLR_MR_DIR}

# Sample (twitter) configs
install -d -m 0755 ${PREFIX}/${DOC_DIR}
cp -r ${BUILD_DIR}/samples ${PREFIX}/${DOC_DIR}/examples
