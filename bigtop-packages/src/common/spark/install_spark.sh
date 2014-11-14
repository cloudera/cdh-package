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
     --build-dir=DIR             path to dist.dir
     --source-dir=DIR            path to package shared files dir
     --prefix=PREFIX             path to install into

  Optional options:
     --doc-dir=DIR               path to install docs into [/usr/share/doc/spark]
     --lib-dir=DIR               path to install Spark home [/usr/lib/spark]
     --installed-lib-dir=DIR     path where lib-dir will end up on target system
     --bin-dir=DIR               path to install bins [/usr/bin]
     --examples-dir=DIR          path to install examples [doc-dir/examples]
     --pyspark-python            executable to use for Python interpreter [python]
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
  -l 'source-dir:' \
  -l 'examples-dir:' \
  -l 'pyspark-python:' \
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
        --source-dir)
        SOURCE_DIR=$2 ; shift 2
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
        --pyspark-python)
        PYSPARK_PYTHON=$2 ; shift 2
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

for var in PREFIX BUILD_DIR SOURCE_DIR; do
  if [ -z "$(eval "echo \$$var")" ]; then
    echo Missing param: $var
    usage
  fi
done

. ${SOURCE_DIR}/packaging_functions.sh

MAN_DIR=${MAN_DIR:-/usr/share/man/man1}
DOC_DIR=${DOC_DIR:-/usr/share/doc/spark}
LIB_DIR=${LIB_DIR:-/usr/lib/spark}
INSTALLED_LIB_DIR=${INSTALLED_LIB_DIR:-/usr/lib/spark}
EXAMPLES_DIR=${EXAMPLES_DIR:-$DOC_DIR/examples}
BIN_DIR=${BIN_DIR:-/usr/bin}
CONF_DIR=${CONF_DIR:-/etc/spark/conf.dist}
SCALA_HOME=${SCALA_HOME:-/usr/share/scala}
PYSPARK_PYTHON=${PYSPARK_PYTHON:-python}

install -d -m 0755 $PREFIX/$LIB_DIR
install -d -m 0755 $PREFIX/$LIB_DIR/bin
install -d -m 0755 $PREFIX/$LIB_DIR/sbin
install -d -m 0755 $PREFIX/$DOC_DIR

install -d -m 0755 $PREFIX/var/lib/spark/
install -d -m 0755 $PREFIX/var/log/spark/
install -d -m 0755 $PREFIX/var/run/spark/
install -d -m 0755 $PREFIX/var/run/spark/work/

install -d -m 0755 $PREFIX/$LIB_DIR/lib
for comp in assembly; do
  tar --wildcards -C $PREFIX/$LIB_DIR/lib -zxf ${BUILD_DIR}/assembly/target/spark-assembly*-dist.tar.gz spark-$comp\*
done

## FIXME: Spark maven assembly needs to include examples into it.
cp ${BUILD_DIR}/examples/target/scala-*/spark-examples*.jar $PREFIX/$LIB_DIR/lib
tar -czf $PREFIX/$LIB_DIR/lib/python.tar.gz -C ${BUILD_DIR}/examples/src/main/python .

# Copy files to the bin and sbin directories
rsync --exclude="*.cmd" ${BUILD_DIR}/bin/* $PREFIX/$LIB_DIR/bin/
rsync --exclude="*.cmd" ${BUILD_DIR}/sbin/* $PREFIX/$LIB_DIR/sbin/

# override the compute-classpath file from the source dir.
cp -a ${SOURCE_DIR}/compute-classpath.sh $PREFIX/$LIB_DIR/bin/

chmod 755 $PREFIX/$LIB_DIR/bin/*
chmod 755 $PREFIX/$LIB_DIR/sbin/*

# FIXME: executor scripts need to reside in bin
touch $PREFIX/$LIB_DIR/RELEASE

# Copy in the configuration files
install -d -m 0755 $PREFIX/$CONF_DIR
cp -a ${BUILD_DIR}/conf/* $PREFIX/$CONF_DIR
cp  $PREFIX/$CONF_DIR/spark-env.sh.template $PREFIX/$CONF_DIR/spark-env.sh
cp  $PREFIX/$CONF_DIR/spark-defaults.conf.template $PREFIX/$CONF_DIR/spark-defaults.conf
ln -s /etc/spark/conf $PREFIX/$LIB_DIR/conf

# Copy in the defaults file
install -d -m 0755 ${PREFIX}/etc/default
cp ${SOURCE_DIR}/spark.default ${PREFIX}/etc/default/spark

# Unpack static UI resources into install_dir/spark where it is expected to be
tar --wildcards -C $PREFIX/$LIB_DIR -zxf ${BUILD_DIR}/assembly/target/spark-assembly*-dist.tar.gz ui-resources/\*

# Copy in the wrappers
install -d -m 0755 $PREFIX/$BIN_DIR
for wrap in sbin/spark-executor bin/spark-shell bin/spark-submit; do
  cat > $PREFIX/$BIN_DIR/`basename $wrap` <<EOF
#!/bin/bash 

# Autodetect JAVA_HOME if not defined
. /usr/lib/bigtop-utils/bigtop-detect-javahome

exec $INSTALLED_LIB_DIR/$wrap "\$@"
EOF
  chmod 755 $PREFIX/$BIN_DIR/`basename $wrap`
done

cat >> $PREFIX/$CONF_DIR/spark-env.sh <<EOF

###
### === IMPORTANT ===
### Change the following to specify a real cluster's Master host
###
export STANDALONE_SPARK_MASTER_HOST=\`hostname\`

export SPARK_MASTER_IP=\$STANDALONE_SPARK_MASTER_HOST

### Let's run everything with JVM runtime, instead of Scala
export SPARK_LAUNCH_WITH_SCALA=0
export SPARK_LIBRARY_PATH=\${SPARK_HOME}/lib
export SCALA_LIBRARY_PATH=\${SPARK_HOME}/lib
export SPARK_MASTER_WEBUI_PORT=18080
export SPARK_MASTER_PORT=7077
export SPARK_WORKER_PORT=7078
export SPARK_WORKER_WEBUI_PORT=18081
export SPARK_WORKER_DIR=/var/run/spark/work
export SPARK_LOG_DIR=/var/log/spark
export SPARK_PID_DIR='/var/run/spark/'

if [ -n "\$HADOOP_HOME" ]; then
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${HADOOP_HOME}/lib/native
fi

export HADOOP_CONF_DIR=\${HADOOP_CONF_DIR:-etc/hadoop/conf}

### Comment above 2 lines and uncomment the following if
### you want to run with scala version, that is included with the package
#export SCALA_HOME=\${SCALA_HOME:-$LIB_DIR/scala}
#export PATH=\$PATH:\$SCALA_HOME/bin

EOF

ln -s /var/run/spark/work $PREFIX/$LIB_DIR/work

cp -r ${BUILD_DIR}/python ${PREFIX}/${INSTALLED_LIB_DIR}/
cp ${BUILD_DIR}/bin/pyspark ${PREFIX}/${INSTALLED_LIB_DIR}/bin/
cat > $PREFIX/$BIN_DIR/pyspark <<EOF
#!/bin/bash

# Autodetect JAVA_HOME if not defined
. /usr/lib/bigtop-utils/bigtop-detect-javahome

export PYSPARK_PYTHON=${PYSPARK_PYTHON}

exec $INSTALLED_LIB_DIR/bin/pyspark "\$@"
EOF
chmod 755 $PREFIX/$BIN_DIR/pyspark

cp ${BUILD_DIR}/{LICENSE,NOTICE} ${PREFIX}/${LIB_DIR}/

# Cloudera specific
install -d -m 0755 $PREFIX/$LIB_DIR/cloudera
cp cloudera/cdh_version.properties $PREFIX/$LIB_DIR/cloudera/

#Currently commenting this since the internal_versionless_symlinks
#function is generating a symlink with a wrong name but once that is fixed
#we need to uncomment the next line and remove the explicit call to ln below
#internal_versionless_symlinks ${PREFIX}/${LIB_DIR}/lib/spark-assembly-*.jar
pushd ${PREFIX}/${LIB_DIR}/lib || \
    { echo "Failed to change dir to ${PREFIX}/${LIB_DIR}/lib" >&2 ; exit 1 ; }
ln -s spark-assembly-*.jar ./spark-assembly.jar
popd

external_versionless_symlinks 'spark' ${PREFIX}/${LIB_DIR}/lib

