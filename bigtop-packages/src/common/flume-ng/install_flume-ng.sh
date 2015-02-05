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
     --build-dir=DIR             path to flumedist.dir
     --prefix=PREFIX             path to install into
     --extra-dir=DIR             path to Bigtop distribution files

  Optional options:
     --doc-dir=DIR               path to install docs into [/usr/share/doc/flume]
     --flume-dir=DIR               path to install flume home [/usr/lib/flume]
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
  -l 'doc-dir-prefix:' \
  -l 'flume-dir:' \
  -l 'bin-dir:' \
  -l 'examples-dir:' \
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
        --doc-dir)
        DOC_DIR=$2 ; shift 2
        ;;
        --doc-dir-prefix)
        DOC_DIR_PREFIX=$2 ; shift 2
        ;;
        --flume-dir)
        FLUME_DIR=$2 ; shift 2
        ;;
        --bin-dir)
        BIN_DIR=$2 ; shift 2
        ;;
        --examples-dir)
        EXAMPLES_DIR=$2 ; shift 2
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

MAN_DIR=${MAN_DIR:-/usr/share/man/man1}
DOC_DIR=${DOC_DIR:-/usr/share/doc/flume-ng}
DOC_DIR_PREFIX=${DOC_DIR_PREFIX:-$PREFIX}
FLUME_DIR=${FLUME_DIR:-/usr/lib/flume-ng}
BIN_DIR=${BIN_DIR:-/usr/lib/flume-ng/bin}
CONF_DIST_DIR=/etc/flume-ng/conf.dist/
ETC_DIR=${ETC_DIR:-/etc/flume-ng}

install -d -m 0755 ${PREFIX}/${FLUME_DIR}

(cd ${PREFIX}/${FLUME_DIR} &&
  tar --strip-components=1 -xvzf ${BUILD_DIR}/flume-ng-dist/target/apache-flume-*-bin.tar.gz)

# Take out useless things or we've installed elsewhere
for x in flume-* \
          .gitignore \
          conf \
          pom.xml \
          CHANGELOG \
          DEVNOTES \
          DISCLAIMER \
          LICENSE \
          NOTICE \
          README \
          RELEASE-NOTES \
          bin/ia64 \
          bin/amd64 \
          cloudera/CHANGES.cloudera.txt \
          cloudera/apply-patches \
          cloudera/build.properties \
          cloudera/patches \
          lib/*.pom; do
  rm -rf ${PREFIX}/$FLUME_DIR/$x 
done


wrapper=$PREFIX/usr/bin/flume-ng
mkdir -p `dirname $wrapper`
cat > $wrapper <<EOF
#!/bin/bash

# Autodetect JAVA_HOME if not defined
. /usr/lib/bigtop-utils/bigtop-detect-javahome

if [ -n "\$FLUME_PID_FILE" ]; then
  echo \$$ > \$FLUME_PID_FILE
fi

exec /usr/lib/flume-ng/bin/flume-ng "\$@"
EOF
chmod 755 $wrapper


install -d -m 0755 $PREFIX/$ETC_DIR/conf.empty
(cd ${BUILD_DIR}/conf && tar cf - .) | (cd $PREFIX/$ETC_DIR/conf.empty && tar xf -)
sed -i -e "s|flume\.log\.dir=.*|flume.log.dir=/var/log/flume-ng|" $PREFIX/$ETC_DIR/conf.empty/log4j.properties
touch $PREFIX/$ETC_DIR/conf.empty/flume.conf
# workaround for CDH-9780
ln -s conf.empty $PREFIX/$ETC_DIR/conf.dist

unlink $PREFIX/$FLUME_DIR/conf || /bin/true
ln -s /etc/flume-ng/conf $PREFIX/$FLUME_DIR/conf

# Docs
install -d -m 0755 ${DOC_DIR_PREFIX}/${DOC_DIR}
for x in CHANGELOG \
          DEVNOTES \
          LICENSE \
          NOTICE \
          README \
          RELEASE-NOTES ; do
  if [ -x $x ] ; then
    cp -r $x ${DOC_DIR_PREFIX}/${DOC_DIR}
  fi
done
mv $PREFIX/$FLUME_DIR/docs/*  ${DOC_DIR_PREFIX}/${DOC_DIR}/
rm -rf $PREFIX/$FLUME_DIR/docs

cp {LICENSE,NOTICE} ${PREFIX}/${FLUME_DIR}/

# Cloudera specific
install -d -m 0755 $PREFIX/$FLUME_DIR/cloudera
cp cloudera/cdh_version.properties $PREFIX/$FLUME_DIR/cloudera/

external_versionless_symlinks 'flume' $PREFIX/$FLUME_DIR/lib

