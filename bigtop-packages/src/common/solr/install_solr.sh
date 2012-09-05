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
     --build-dir=DIR             path to dist dir
     --prefix=PREFIX             path to install into

  Optional options:
     --doc-dir=DIR               path to install docs into [/usr/share/doc/solr]
     --lib-dir=DIR               path to install bits [/usr/lib/solr]
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

MAN_DIR=${MAN_DIR:-/usr/share/man/man1}
DOC_DIR=${DOC_DIR:-/usr/share/doc/solr}
LIB_DIR=${LIB_DIR:-/usr/lib/solr}
INSTALLED_LIB_DIR=${INSTALLED_LIB_DIR:-/usr/lib/solr}
EXAMPLES_DIR=${EXAMPLES_DIR:-$DOC_DIR/examples}
BIN_DIR=${BIN_DIR:-/usr/bin}
CONF_DIR=${CONF_DIR:-/etc/solr/conf}

VAR_DIR=$PREFIX/var

install -d -m 0755 $PREFIX/$LIB_DIR
cp -ra ${BUILD_DIR}/dist/*.*ar $PREFIX/$LIB_DIR
cp -ra ${BUILD_DIR}/dist/solrj-lib $PREFIX/$LIB_DIR/lib
cp -ra ${BUILD_DIR}/contrib $PREFIX/$LIB_DIR

cp -ra ${BUILD_DIR}/dist/*.*ar $PREFIX/$LIB_DIR
cp -ra ${BUILD_DIR}/dist/solrj-lib $PREFIX/$LIB_DIR/lib
cp -ra ${BUILD_DIR}/contrib $PREFIX/$LIB_DIR

install -d -m 0755 $PREFIX/$LIB_DIR/bin
cp -a ${BUILD_DIR}/example/cloud-scripts/*.sh $PREFIX/$LIB_DIR/bin

install -d -m 0755 $PREFIX/$DOC_DIR
cp -a  ${BUILD_DIR}/*.txt $PREFIX/$DOC_DIR
cp -ra ${BUILD_DIR}/docs/* $PREFIX/$DOC_DIR
cp -a ${BUILD_DIR}/example/ $PREFIX/$DOC_DIR/

# Copy in the configuration files
install -d -m 0755 $PREFIX/${CONF_DIR}.dist
cp -ra ${BUILD_DIR}/example/multicore/* $PREFIX/${CONF_DIR}.dist
rm -rf $PREFIX/${CONF_DIR}.dist/exampledocs
ln -s  ${CONF_DIR} $PREFIX/$LIB_DIR/conf
# FIXME: we have to find a better way to do the following
for core in core0 core1 ; do
  sed -i -e '/<dataDir>.*<\/dataDir>/s#^.*$#<dataDir>/var/lib/solr/'$core'</dataDir>#' \
    $PREFIX/${CONF_DIR}.dist/$core/conf/solrconfig.xml
done

# Copy in the wrapper
install -d -m 0755 $PREFIX/$BIN_DIR
cat > $PREFIX/$BIN_DIR/solr <<EOF
#!/bin/sh

# Autodetect JAVA_HOME if not defined
if [ -e /usr/libexec/bigtop-detect-javahome ]; then
  . /usr/libexec/bigtop-detect-javahome
elif [ -e /usr/lib/bigtop-utils/bigtop-detect-javahome ]; then
  . /usr/lib/bigtop-utils/bigtop-detect-javahome
fi

cd $INSTALLED_LIB_DIR/jetty
exec java -jar start.jar "\$@"
EOF
chmod 755 $PREFIX/$BIN_DIR/solr

# Zookeeper log and tx log directory
install -d -m 0755 $VAR_DIR/log/solr
install -d -m 0755 $VAR_DIR/run/solr
install -d -m 0755 $VAR_DIR/lib/solr

# FIXME: we probably should run Solr via bigtop-tomcat
install -d -m 0755 $VAR_DIR/lib/solr/jetty
install -d -m 0755 $VAR_DIR/lib/solr/jetty/webapps
cp -a  ${BUILD_DIR}/example/start.jar $VAR_DIR/lib/solr/jetty
cp -ra ${BUILD_DIR}/example/etc $VAR_DIR/lib/solr/jetty
cp -ra ${BUILD_DIR}/example/contexts $VAR_DIR/lib/solr/jetty
cp -ra ${BUILD_DIR}/example/lib $VAR_DIR/lib/solr/jetty
ln -s  $LIB_DIR/conf $VAR_DIR/lib/solr/jetty/solr
ln -s  $LIB_DIR/`basename $PREFIX/$LIB_DIR/*.war` $VAR_DIR/lib/solr/jetty/webapps/solr.war

# Cloudera specific
#install -d -m 0755 $PREFIX/$LIB_DIR/cloudera
#cp cloudera/cdh_version.properties $PREFIX/$LIB_DIR/cloudera/
