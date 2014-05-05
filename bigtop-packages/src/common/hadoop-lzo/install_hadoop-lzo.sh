#!/bin/bash

set -e

usage() {
  echo "
usage: $0 <options>
  Required not-so-options:
     --build-dir=DIR             path to source / build directory
     --prefix=PREFIX             path to destination "root" file system

  Optional options:
     --hadoop-home=DIR           path of destination hadoop dir
     --mr1-home=DIR              path of destination mr1 dir
     --name                      name of the package(s) being generated
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
        --hadoop-home)
        HADOOP_HOME=$2 ; shift 2
        ;;
        --mr1-home)
        MR1_HOME=$2 ; shift 2
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

HADOOP_HOME=${HADOOP_HOME:-/usr/lib/hadoop}
MR1_HOME=${MR1_HOME:-/usr/lib/hadoop-0.20-mapreduce}
NAME=${NAME:-hadoop-lzo}

ls -lR ${BUILD_DIR}

install -d ${PREFIX}/${HADOOP_HOME}/lib
install -d ${PREFIX}/${HADOOP_HOME}/lib/native
install -m 644 ${BUILD_DIR}/build/${NAME}-*.jar ${PREFIX}/${HADOOP_HOME}/lib/
ln -s `basename ${PREFIX}/${HADOOP_HOME}/lib/${NAME}-*.jar` ${PREFIX}/${HADOOP_HOME}/lib/hadoop-lzo.jar
for file in `find ${BUILD_DIR}/build/native/ -name libgplcompression.*`; do
    install $file ${PREFIX}/${HADOOP_HOME}/lib/native/
done
chmod -R 755 ${PREFIX}/${HADOOP_HOME}/lib/native

# Install symbolic links in MR1 locations
install -d ${PREFIX}/${MR1_HOME}/lib
install -d ${PREFIX}/${MR1_HOME}/lib/native
for file in ${PREFIX}/${HADOOP_HOME}/lib/*.jar; do
    ln -s ../../hadoop/lib/${file/*\//} ${PREFIX}/${MR1_HOME}/lib/
done
for file in ${PREFIX}/${HADOOP_HOME}/lib/native/libgplcompression.*; do
    ln -s ../../../hadoop/lib/native/${file/*\//} ${PREFIX}/${MR1_HOME}/lib/native/
done
chmod -R 755 ${PREFIX}/${MR1_HOME}/lib/native

