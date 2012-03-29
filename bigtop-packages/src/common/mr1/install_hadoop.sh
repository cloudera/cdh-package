#!/bin/bash -x
# Copyright 2009 Cloudera, inc.

set -ex

usage() {
  echo "
usage: $0 <options>
  Required not-so-options:
     --cloudera-source-dir=DIR   path to cloudera distribution files
     --build-dir=DIR             path to hive/build/dist
     --prefix=PREFIX             path to install into

  Optional options:
     --native-build-string       eg Linux-amd-64 (optional - no native installed if not set)
     ... [ see source for more similar options ]
  "
  exit 1
}

OPTS=$(getopt \
  -n $0 \
  -o '' \
  -l 'cloudera-source-dir:' \
  -l 'prefix:' \
  -l 'build-dir:' \
  -l 'native-build-string:' \
  -l 'installed-lib-dir:' \
  -l 'lib-dir:' \
  -l 'client-dir:' \
  -l 'system-lib-dir:' \
  -l 'src-dir:' \
  -l 'etc-dir:' \
  -l 'doc-dir:' \
  -l 'man-dir:' \
  -l 'example-dir:' \
  -l 'apache-branch:' \
  -- "$@")

if [ $? != 0 ] ; then
    usage
fi

eval set -- "$OPTS"
while true ; do
    case "$1" in
        --cloudera-source-dir)
        CLOUDERA_SOURCE_DIR=$2 ; shift 2
        ;;
        --prefix)
        PREFIX=$2 ; shift 2
        ;;
        --lib-dir)
        LIB_DIR=$2 ; shift 2
        ;;
        --hadoop-dir)
        CLIENT_DIR=$2 ; shift 2
        ;;
        --system-lib-dir)
        SYSTEM_LIB_DIR=$2 ; shift 2
        ;;
        --build-dir)
        BUILD_DIR=$2 ; shift 2
        ;;
        --native-build-string)
        NATIVE_BUILD_STRING=$2 ; shift 2
        ;;
        --doc-dir)
        DOC_DIR=$2 ; shift 2
        ;;
        --etc-dir)
        ETC_DIR=$2 ; shift 2
        ;;
        --installed-lib-dir)
        INSTALLED_LIB_DIR=$2 ; shift 2
        ;;
        --man-dir)
        MAN_DIR=$2 ; shift 2
        ;;
        --example-dir)
        EXAMPLE_DIR=$2 ; shift 2
        ;;
        --apache-branch)
        APACHE_BRANCH=$2 ; shift 2
        ;;
        --src-dir)
        SRC_DIR=$2 ; shift 2
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

for var in CLOUDERA_SOURCE_DIR PREFIX BUILD_DIR APACHE_BRANCH; do
  if [ -z "$(eval "echo \$$var")" ]; then
    echo Missing param: $var
    usage
  fi
done

LIB_DIR=${LIB_DIR:-$PREFIX/usr/lib/hadoop-$APACHE_BRANCH}
CLIENT_DIR=${CLIENT_DIR:-$PREFIX/usr/lib/hadoop/client-0.20}
SYSTEM_LIB_DIR=${SYSTEM_LIB_DIR:-/usr/lib}
BIN_DIR=${BIN_DIR:-$PREFIX/usr/bin}
DOC_DIR=${DOC_DIR:-$PREFIX/usr/share/doc/hadoop-$APACHE_BRANCH}
MAN_DIR=${MAN_DIR:-$PREFIX/usr/man}
EXAMPLE_DIR=${EXAMPLE_DIR:-$DOC_DIR/examples}
SRC_DIR=${SRC_DIR:-$PREFIX/usr/src/hadoop-$APACHE_BRANCH}
ETC_DIR=${ETC_DIR:-$PREFIX/etc/hadoop}

INSTALLED_LIB_DIR=${INSTALLED_LIB_DIR:-/usr/lib/hadoop-$APACHE_BRANCH}

# TODO(todd) right now we're using bin-package, so we don't copy
# src/ into the dist. otherwise this would be BUILD_DIR/src
HADOOP_SRC_DIR=$BUILD_DIR/../../src

mkdir -p $LIB_DIR
(cd $BUILD_DIR && tar cf - .) | (cd $LIB_DIR && tar xf - )

# Create symlinks to preserve old jar names
# Also create symlinks of versioned jars to jars without version names, which other
# packages can depend on
(cd $LIB_DIR &&
for j in hadoop-*.jar; do
  if [[ $j =~ hadoop-([a-zA-Z]+)-(.*).jar ]]; then
    name=${BASH_REMATCH[1]}
    ver=${BASH_REMATCH[2]}
    ln -s hadoop-$name-$ver.jar hadoop-$ver-$name.jar
    ln -s hadoop-$name-$ver.jar hadoop-$name.jar
  fi
done)

# Take out things we've installed elsewhere
for x in docs lib/native c++ src conf usr/bin/fuse_dfs contrib/fuse contrib/hod \
         hadoop-client.list pids lib/hadoop-{annotations,auth,common,hdfs}* ; do
  rm -rf $LIB_DIR/$x 
done

# Make bin wrappers
mkdir -p $BIN_DIR

for bin_wrapper in hadoop-$APACHE_BRANCH ; do
  wrapper=$BIN_DIR/$bin_wrapper
  cat > $wrapper <<EOF
#!/bin/sh

export HADOOP_HOME=$INSTALLED_LIB_DIR
export HADOOP_MAPRED_HOME=$INSTALLED_LIB_DIR
export HADOOP_LIBEXEC_DIR=$SYSTEM_LIB_DIR/hadoop/libexec
export HADOOP_CONF_DIR=/etc/hadoop/conf

exec $INSTALLED_LIB_DIR/bin/hadoop "\$@"
EOF
  chmod 755 $wrapper
done

# Provide a mapred link for MR2 hadoop launcher script
ln -s hadoop $LIB_DIR/bin/mapred

# Link examples to /usr/share
mkdir -p $EXAMPLE_DIR
for x in $LIB_DIR/*examples*jar ; do
  INSTALL_LOC=`echo $x | sed -e "s,$LIB_DIR,$INSTALLED_LIB_DIR,"`
  ln -sf $INSTALL_LOC $EXAMPLE_DIR/
done
# And copy the source
mkdir -p $EXAMPLE_DIR/src
cp -a $HADOOP_SRC_DIR/examples/* $EXAMPLE_DIR/src

# Install docs
mkdir -p $DOC_DIR
cp -r ${BUILD_DIR}/../../docs/* $DOC_DIR

# man pages
mkdir -p $MAN_DIR/man1
cp ${CLOUDERA_SOURCE_DIR}/hadoop-$APACHE_BRANCH.1.gz $MAN_DIR/man1/

if [ ! -z "$NATIVE_BUILD_STRING" ]; then
  # Native compression libs
  mkdir -p $LIB_DIR/lib/native/
  ln -s /usr/lib/hadoop/lib/native $LIB_DIR/lib/native/${NATIVE_BUILD_STRING}

  # Pipes
  mkdir -p $PREFIX/$SYSTEM_LIB_DIR $PREFIX/usr/include
  cp ${BUILD_DIR}/c++/${NATIVE_BUILD_STRING}/lib/libhadooppipes.a \
      ${BUILD_DIR}/c++/${NATIVE_BUILD_STRING}/lib/libhadooputils.a \
      $PREFIX/$SYSTEM_LIB_DIR
  cp -r ${BUILD_DIR}/c++/${NATIVE_BUILD_STRING}/include/hadoop $PREFIX/usr/include/
fi

# Creating hadoop-0.20-client
install -d -m 0755 ${CLIENT_DIR}
for file in `cat ${BUILD_DIR}/hadoop-client.list` ; do
  for target in ${LIB_DIR}/{,lib}/$file ; do
    [ -e $target ] && ln -fs ${target#$PREFIX}  ${CLIENT_DIR}/$file && continue 2
  done
  ln -s ../client/$file ${CLIENT_DIR}/$file
done

# Cloudera specific
rm -rf $LIB_DIR/cloudera*
install -d -m 0755 $LIB_DIR/cloudera
cp cloudera/cdh_version.properties $LIB_DIR/cloudera
