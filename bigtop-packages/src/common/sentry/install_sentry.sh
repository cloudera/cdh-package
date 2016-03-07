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

set -ex

usage() {
  echo "
usage: $0 <options>
  Required not-so-options:
     --build-dir=DIR             path to sentry dist.dir
     --prefix=PREFIX             path to install into

  Optional options:
     --doc-dir=DIR               path to install docs into [/usr/share/doc/sentry]
     --lib-dir=DIR               path to install hive home [/usr/lib/sentry]
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
  -l 'lib-dir:' \
  -l 'bin-dir:' \
  -l 'conf-dir:' \
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
        --bin-dir)
        BIN_DIR=$2 ; shift 2
        ;;
        --conf-dir)
        CONF_DIR=$2 ; shift 2
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

CONF_DIR=${CONF_DIR:-${PREFIX}/etc/sentry/conf.dist}
LIB_DIR=${LIB_DIR:-$PREFIX/usr/lib/sentry}
BIN_DIR=${BIN_DIR:-$PREFIX/usr/bin}
PLUGIN_DIR=${LIB_DIR}/lib/plugins

TARBALL=sentry-dist/target/apache-sentry-${FULL_VERSION}-bin.tar.gz
DIRECTORY=${TARBALL/.tar.gz/}
(cd `dirname ${TARBALL}` && tar xzf `basename ${TARBALL}`)

install -d -m 0755 ${LIB_DIR}
mv ${DIRECTORY}/{bin,lib,scripts} ${LIB_DIR}/
chmod 0755 ${LIB_DIR}/*

# Cleaning up the lib dir
(cd ${LIB_DIR}/lib; rm -f *-test-*.jar randomizedtesting-runner*.jar)

mv ${BUILD_DIR}/LICENSE.txt ${LIB_DIR}/
mv ${BUILD_DIR}/NOTICE.txt ${LIB_DIR}/

install -d -m 0755 ${BIN_DIR}
wrapper=$BIN_DIR/sentry
cat >>$wrapper <<EOF
#!/bin/bash

# Autodetect JAVA_HOME if not defined
. /usr/lib/bigtop-utils/bigtop-detect-javahome

export HADOOP_HOME=\${HADOOP_HOME:-/usr/lib/hadoop}
export SENTRY_HOME=\${SENTRY_HOME:-/usr/lib/sentry}
exec /usr/lib/sentry/bin/sentry "\$@"
EOF

chmod 755 $wrapper

install -d -m 0755 ${CONF_DIR}
cp ${EXTRA_DIR}/sentry-site.xml ${CONF_DIR}/

install -d -m 0755 ${PREFIX}/var/lib/sentry
install -d -m 0755 ${PREFIX}/var/log/sentry
install -d -m 0755 ${PREFIX}/var/run/sentry

# Cloudera specific
install -d -m 0755 $LIB_DIR/cloudera
cp cloudera/cdh_version.properties $LIB_DIR/cloudera/

internal_versionless_symlinks ${LIB_DIR}/lib/sentry*.jar

# Shaded jar added for impala to consume with Sentry 1.5.0
internal_versionless_symlinks ${LIB_DIR}/lib/impala/sentry*.jar

external_versionless_symlinks 'sentry solr-sentry' ${LIB_DIR}/lib ${LIB_DIR}/lib/server

internal_versionless_symlinks ${PLUGIN_DIR}/sentry*.jar

# Backwards compatibility with CM 5.0.x
install -d -m 0755 ${PREFIX}/usr/lib/hive/sentry/cloudera
ln -s ../../../sentry/cloudera/cdh_version.properties ${PREFIX}/usr/lib/hive/sentry/cloudera/
