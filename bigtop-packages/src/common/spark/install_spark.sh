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
HADOOP_HOME=${HADOOP_HOME:-/usr/lib/hadoop}
HADOOP_HDFS_HOME=${HADOOP_HDFS_HOME:-/usr/lib/hadoop-hdfs}
HADOOP_MAPRED_HOME=${HADOOP_MAPRED_HOME:-/usr/lib/hadoop-mapreduce}
HADOOP_YARN_HOME=${HADOOP_YARN_HOME:-/usr/lib/hadoop-yarn}
HADOOP_YARN_LIB=$PREFIX/$HADOOP_YARN_HOME/lib
FLUME_HOME=${FLUME_HOME:-/usr/lib/flume-ng}
HIVE_HOME=${HIVE_HOME:-/usr/lib/hive}
PARQUET_HOME=${PARQUET_HOME:-/usr/lib/paquet}
AVRO_HOME=${AVRO_HOME:-/usr/lib/avro}

install -d -m 0755 $PREFIX/$LIB_DIR
install -d -m 0755 $PREFIX/$LIB_DIR/bin
install -d -m 0755 $PREFIX/$LIB_DIR/sbin
install -d -m 0755 $PREFIX/$DOC_DIR
install -d -m 0755 $HADOOP_YARN_LIB

install -d -m 0755 $PREFIX/var/lib/spark/
install -d -m 0755 $PREFIX/var/log/spark/
install -d -m 0755 $PREFIX/var/run/spark/
install -d -m 0755 $PREFIX/var/run/spark/work/

install -d -m 0755 $PREFIX/$LIB_DIR/lib


SPARK_TMP=spark_tmp
rm -rf $SPARK_TMP ; mkdir $SPARK_TMP


tar --wildcards -C $SPARK_TMP --strip-components=1 -xvzf build/*.tar.gz \*/\*
mv $SPARK_TMP/lib/spark-assembly*.jar $PREFIX/$LIB_DIR/lib

## FIXME: Spark maven assembly needs to include examples into it.
mv $SPARK_TMP/lib/spark-examples*.jar $PREFIX/$LIB_DIR/lib

#This is so that users can optionally use spark-*-yarn-shuffle.jar - see
#https://jira.cloudera.com/browse/CDH-25073 for details
mv $SPARK_TMP/lib/spark-*-yarn-shuffle.jar $HADOOP_YARN_LIB
tar -czf $PREFIX/$LIB_DIR/lib/python.tar.gz -C $SPARK_TMP/examples/src/main/python .

# Copy files to the bin and sbin directories
rsync --exclude="*.cmd" $SPARK_TMP/bin/* $PREFIX/$LIB_DIR/bin/
rsync --exclude="*.cmd" $SPARK_TMP/sbin/* $PREFIX/$LIB_DIR/sbin/

chmod 755 $PREFIX/$LIB_DIR/bin/*
chmod 755 $PREFIX/$LIB_DIR/sbin/*

# FIXME: executor scripts need to reside in bin
touch $PREFIX/$LIB_DIR/RELEASE

# Copy in the configuration files
install -d -m 0755 $PREFIX/$CONF_DIR
cp -a $SPARK_TMP/conf/* $PREFIX/$CONF_DIR
cp  $PREFIX/$CONF_DIR/spark-env.sh.template $PREFIX/$CONF_DIR/spark-env.sh
cp  $PREFIX/$CONF_DIR/spark-defaults.conf.template $PREFIX/$CONF_DIR/spark-defaults.conf
ln -s /etc/spark/conf $PREFIX/$LIB_DIR/conf

# Copy in the defaults file
install -d -m 0755 ${PREFIX}/etc/default
cp ${SOURCE_DIR}/spark.default ${PREFIX}/etc/default/spark

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

export HADOOP_CONF_DIR=\${HADOOP_CONF_DIR:-/etc/hadoop/conf}

if [[ -d \$SPARK_HOME/python ]]
then
    for i in `ls \$SPARK_HOME/python/*.jar`
    do
        SPARK_DIST_CLASSPATH=\${SPARK_DIST_CLASSPATH}:\$i
    done
fi

SPARK_DIST_CLASSPATH="\$SPARK_DIST_CLASSPATH:\$SPARK_LIBRARY_PATH/spark-assembly.jar"
SPARK_DIST_CLASSPATH="\$SPARK_DIST_CLASSPATH:$HADOOP_CONF_DIR"
SPARK_DIST_CLASSPATH="\$SPARK_DIST_CLASSPATH:$HADOOP_HOME/lib/*"
SPARK_DIST_CLASSPATH="\$SPARK_DIST_CLASSPATH:$HADOOP_HOME/*"
SPARK_DIST_CLASSPATH="\$SPARK_DIST_CLASSPATH:$HADOOP_HDFS_HOME/lib/*"
SPARK_DIST_CLASSPATH="\$SPARK_DIST_CLASSPATH:$HADOOP_HDFS_HOME/*"
SPARK_DIST_CLASSPATH="\$SPARK_DIST_CLASSPATH:$HADOOP_MAPRED_HOME/lib/*"
SPARK_DIST_CLASSPATH="\$SPARK_DIST_CLASSPATH:$HADOOP_MAPRED_HOME/*"
SPARK_DIST_CLASSPATH="\$SPARK_DIST_CLASSPATH:$HADOOP_YARN_HOME/lib/*"
SPARK_DIST_CLASSPATH="\$SPARK_DIST_CLASSPATH:$HADOOP_YARN_HOME/*"
SPARK_DIST_CLASSPATH="\$SPARK_DIST_CLASSPATH:$HIVE_HOME/lib/*"
SPARK_DIST_CLASSPATH="\$SPARK_DIST_CLASSPATH:$FLUME_HOME/lib/*"
SPARK_DIST_CLASSPATH="\$SPARK_DIST_CLASSPATH:$PARQUET_HOME/lib/*"
SPARK_DIST_CLASSPATH="\$SPARK_DIST_CLASSPATH:$AVRO_HOME/lib/*"
EOF

ln -s /var/run/spark/work $PREFIX/$LIB_DIR/work

cp -r $SPARK_TMP/python ${PREFIX}/${INSTALLED_LIB_DIR}/
cp $SPARK_TMP/bin/pyspark ${PREFIX}/${INSTALLED_LIB_DIR}/bin/
cat > $PREFIX/$BIN_DIR/pyspark <<EOF
#!/bin/bash

# Autodetect JAVA_HOME if not defined
. /usr/lib/bigtop-utils/bigtop-detect-javahome

export PYSPARK_PYTHON=\${PYSPARK_PYTHON:-${PYSPARK_PYTHON}}

exec $INSTALLED_LIB_DIR/bin/pyspark "\$@"
EOF
chmod 755 $PREFIX/$BIN_DIR/pyspark

cp $SPARK_TMP/{LICENSE,NOTICE} ${PREFIX}/${LIB_DIR}/

# Cloudera specific
install -d -m 0755 $PREFIX/$LIB_DIR/cloudera
cp cloudera/cdh_version.properties $PREFIX/$LIB_DIR/cloudera/

internal_versionless_symlinks \
   ${PREFIX}/${LIB_DIR}/lib/spark-*.jar

#Temporary fix to workaround cdh-24083.  This needs to be eliminated in the
#next major release of CDH
install -d -m 0755 $PREFIX/$LIB_DIR/assembly/lib
install -d -m 0755 $PREFIX/$LIB_DIR/examples/lib

pushd $PREFIX/$LIB_DIR/assembly/lib
ln -s ../../lib/spark-assembly-*.jar .
ln -s ../../lib/spark-assembly-*.jar ./spark-assembly.jar
popd

pushd $PREFIX/$LIB_DIR/examples/lib
ln -s ../../lib/spark-examples-*.jar .
ln -s ../../lib/python.tar.gz .
popd

#end of temporary workaround

internal_versionless_symlinks ${HADOOP_YARN_LIB}/spark*.jar

external_versionless_symlinks 'spark' ${PREFIX}/${LIB_DIR}/lib

rm -rf $SPARK_TMP
