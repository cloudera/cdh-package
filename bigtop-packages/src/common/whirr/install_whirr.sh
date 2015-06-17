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
     --build-dir=DIR             path to Whirr dist.dir
     --prefix=PREFIX             path to install into

  Optional options:
     --doc-dir=DIR               path to install docs into [/usr/share/doc/whirr]
     --lib-dir=DIR               path to install Whirr home [/usr/lib/whirr]
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

MAN_DIR=$PREFIX/usr/share/man/man1
DOC_DIR=${DOC_DIR:-$PREFIX/usr/share/doc/whirr}
LIB_DIR=${LIB_DIR:-$PREFIX/usr/lib/whirr}
INSTALLED_LIB_DIR=${INSTALLED_LIB_DIR:-/usr/lib/whirr}
EXAMPLES_DIR=${EXAMPLES_DIR:-$DOC_DIR/examples}
BIN_DIR=${BIN_DIR:-$PREFIX/usr/bin}

# First we'll move everything into lib
install -d -m 0755 $LIB_DIR
(cd $BUILD_DIR && tar -cf - .) | (cd $LIB_DIR && tar -xf -)

# Copy in the /usr/bin/whirr wrapper
install -d -m 0755 $BIN_DIR
cat > $BIN_DIR/whirr <<EOF
#!/bin/bash

# Autodetect JAVA_HOME if not defined
. /usr/lib/bigtop-utils/bigtop-detect-javahome

exec $INSTALLED_LIB_DIR/bin/whirr "\$@"
EOF
chmod 755 $BIN_DIR/whirr

install -d -m 0755 $MAN_DIR
gzip -c whirr.1 > $MAN_DIR/whirr.1.gz

# Move the docs, but leave a symlink in place for compat. reasons
install -d -m 0755 $DOC_DIR
mv $LIB_DIR/docs/* $DOC_DIR
mv $LIB_DIR/{NOTICE.txt,LICENSE.txt,BUILD.txt,CHANGES.txt,doap_Whirr.rdf,README.txt} $DOC_DIR

# Remove some bits which sould not be shipped.
for dir in src services pom.xml patch-stamp examples debian core cli build-tools bigtop-empty docs cloudera/patches cloudera/apply-patches cloudera/build.properties cloudera/CHANGES.cloudera.txt 'whirr*tar.gz'
do
  rm -rf $LIB_DIR/$dir
done

# leave a doc symlink in place for compat. reasons
ln -s /${DOC_DIR/#$PREFIX/} $LIB_DIR/docs

cp ${BUILD_DIR}/{LICENSE,NOTICE}.txt ${LIB_DIR}/

# Cloudera specific
install -d -m 0755 $LIB_DIR/cloudera
cp cloudera/cdh_version.properties $LIB_DIR/cloudera/

internal_versionless_symlinks ${LIB_DIR}/lib/whirr*.jar

external_versionless_symlinks 'whirr' ${LIB_DIR}/lib

