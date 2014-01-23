#!/bin/bash -x
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
     --distro-dir=DIR            path to distro specific files (debian/RPM)
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
  -l 'prefix:' \
  -l 'distro-dir:' \
  -l 'source-dir:' \
  -l 'build-dir:' \
  -l 'hadoop-version:' \
  -l 'native-build-string:' \
  -l 'installed-lib-dir:' \
  -l 'hadoop-dir:' \
  -l 'httpfs-dir:' \
  -l 'hdfs-dir:' \
  -l 'yarn-dir:' \
  -l 'mapreduce-dir:' \
  -l 'client-dir:' \
  -l 'system-include-dir:' \
  -l 'system-lib-dir:' \
  -l 'system-libexec-dir:' \
  -l 'hadoop-etc-dir:' \
  -l 'httpfs-etc-dir:' \
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
        --prefix)
        PREFIX=$2 ; shift 2
        ;;
        --distro-dir)
        DISTRO_DIR=$2 ; shift 2
        ;;
        --httpfs-dir)
        HTTPFS_DIR=$2 ; shift 2
        ;;
        --hadoop-dir)
        HADOOP_DIR=$2 ; shift 2
        ;;
        --hadoop-version)
        HADOOP_VERSION=$2 ; shift 2
        ;;
        --hdfs-dir)
        HDFS_DIR=$2 ; shift 2
        ;;
        --yarn-dir)
        YARN_DIR=$2 ; shift 2
        ;;
        --mapreduce-dir)
        MAPREDUCE_DIR=$2 ; shift 2
        ;;
        --mapreduce-mr1-dir)
        MAPREDUCE_MR1_DIR=$2 ; shift 2
        ;;
        --client-dir)
        CLIENT_DIR=$2 ; shift 2
        ;;
        --client-mr1-dir)
        CLIENT_MR1_DIR=$2 ; shift 2
        ;;
        --system-include-dir)
        SYSTEM_INCLUDE_DIR=$2 ; shift 2
        ;;
        --system-lib-dir)
        SYSTEM_LIB_DIR=$2 ; shift 2
        ;;
        --system-libexec-dir)
        SYSTEM_LIBEXEC_DIR=$2 ; shift 2
        ;;
        --build-dir)
        BUILD_DIR=$2 ; shift 2
        ;;
        --source-dir)
        SOURCE_DIR=$2 ; shift 2
        ;;
        --native-build-string)
        NATIVE_BUILD_STRING=$2 ; shift 2
        ;;
        --doc-dir)
        DOC_DIR=$2 ; shift 2
        ;;
        --hadoop-etc-dir)
        HADOOP_ETC_DIR=$2 ; shift 2
        ;;
        --httpfs-etc-dir)
        HTTPFS_ETC_DIR=$2 ; shift 2
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

for var in PREFIX BUILD_DIR; do
  if [ -z "$(eval "echo \$$var")" ]; then
    echo Missing param: $var
    usage
  fi
done

HADOOP_DIR=${HADOOP_DIR:-$PREFIX/usr/lib/hadoop}
HDFS_DIR=${HDFS_DIR:-$PREFIX/usr/lib/hadoop-hdfs}
YARN_DIR=${YARN_DIR:-$PREFIX/usr/lib/hadoop-yarn}
MAPREDUCE_DIR=${MAPREDUCE_DIR:-$PREFIX/usr/lib/hadoop-mapreduce}
MAPREDUCE_MR1_DIR=${MAPREDUCE_MR1_DIR:-$PREFIX/usr/lib/hadoop-0.20-mapreduce}
CLIENT_DIR=${CLIENT_DIR:-$PREFIX/usr/lib/hadoop/client}
CLIENT_MR1_DIR=${CLIENT_MR1_DIR:-$PREFIX/usr/lib/hadoop/client-0.20}
HTTPFS_DIR=${HTTPFS_DIR:-$PREFIX/usr/lib/hadoop-httpfs}
SYSTEM_LIB_DIR=${SYSTEM_LIB_DIR:-/usr/lib}
BIN_DIR=${BIN_DIR:-$PREFIX/usr/bin}
DOC_DIR=${DOC_DIR:-$PREFIX/usr/share/doc/hadoop}
MAN_DIR=${MAN_DIR:-$PREFIX/usr/man}
SYSTEM_INCLUDE_DIR=${SYSTEM_INCLUDE_DIR:-$PREFIX/usr/include}
SYSTEM_LIBEXEC_DIR=${SYSTEM_LIBEXEC_DIR:-$PREFIX/usr/libexec}
EXAMPLE_DIR=${EXAMPLE_DIR:-$DOC_DIR/examples}
HADOOP_ETC_DIR=${HADOOP_ETC_DIR:-$PREFIX/etc/hadoop}
HTTPFS_ETC_DIR=${HTTPFS_ETC_DIR:-$PREFIX/etc/hadoop-httpfs}
BASH_COMPLETION_DIR=${BASH_COMPLETION_DIR:-$PREFIX/etc/bash_completion.d}

INSTALLED_HADOOP_DIR=${INSTALLED_HADOOP_DIR:-/usr/lib/hadoop}
HADOOP_NATIVE_LIB_DIR=${HADOOP_DIR}/lib/native


##Needed for some distros to find ldconfig
export PATH="/sbin/:$PATH"

# Make bin wrappers
mkdir -p $BIN_DIR

for component in $HADOOP_DIR/bin/hadoop $HDFS_DIR/bin/hdfs $YARN_DIR/bin/yarn $MAPREDUCE_DIR/bin/mapred ; do
  wrapper=$BIN_DIR/${component#*/bin/}
  cat > $wrapper <<EOF
#!/bin/sh

# Autodetect JAVA_HOME if not defined
. /usr/lib/bigtop-utils/bigtop-detect-javahome

export HADOOP_LIBEXEC_DIR=/${SYSTEM_LIBEXEC_DIR#${PREFIX}}

exec ${component#${PREFIX}} "\$@"
EOF
  chmod 755 $wrapper
done

#libexec
install -d -m 0755 ${SYSTEM_LIBEXEC_DIR}
cp ${BUILD_DIR}/libexec/* ${SYSTEM_LIBEXEC_DIR}/
cp ${DISTRO_DIR}/hadoop-layout.sh ${SYSTEM_LIBEXEC_DIR}/
install -m 0755 ${DISTRO_DIR}/init-hdfs.sh ${SYSTEM_LIBEXEC_DIR}/

# hadoop jar
install -d -m 0755 ${HADOOP_DIR}
cp ${BUILD_DIR}/share/hadoop/common/*.jar ${HADOOP_DIR}/
cp ${BUILD_DIR}/share/hadoop/common/lib/hadoop-auth*.jar ${HADOOP_DIR}/
cp ${BUILD_DIR}/share/hadoop/mapreduce/lib/hadoop-annotations*.jar ${HADOOP_DIR}/
install -d -m 0755 ${MAPREDUCE_DIR}
cp ${BUILD_DIR}/share/hadoop/mapreduce/hadoop-mapreduce*.jar ${MAPREDUCE_DIR}
cp ${BUILD_DIR}/share/hadoop/tools/lib/*.jar ${MAPREDUCE_DIR}
install -d -m 0755 ${HDFS_DIR}
cp ${BUILD_DIR}/share/hadoop/hdfs/*.jar ${HDFS_DIR}/
install -d -m 0755 ${YARN_DIR}
cp ${BUILD_DIR}/share/hadoop/yarn/hadoop-yarn*.jar ${YARN_DIR}/
chmod 644 ${HADOOP_DIR}/*.jar ${MAPREDUCE_DIR}/*.jar ${HDFS_DIR}/*.jar ${YARN_DIR}/*.jar
# FIXME MR1: the following needs to be rationalized so we don't have to use globbing
install -d -m 0755 ${MAPREDUCE_MR1_DIR}/sbin
cp -r ${BUILD_DIR}/share/hadoop/mapreduce1/* ${MAPREDUCE_MR1_DIR}
# Take out contrib bits that we don't officially support
for x in contrib/vaidya contrib/thriftfs contrib/hod contrib/failmon contrib/datajoin contrib/index ; do 
  rm -rf ${MAPREDUCE_MR1_DIR}/$x 
done

# Remove the convenience symlink so we can copy the stuff over
rm ${MAPREDUCE_MR1_DIR}/bin
cp -r ${BUILD_DIR}/bin-mapreduce1 ${MAPREDUCE_MR1_DIR}/bin
cp -r ${BUILD_DIR}/sbin/Linux* ${MAPREDUCE_MR1_DIR}/sbin
ln -s /etc/hadoop/conf ${MAPREDUCE_MR1_DIR}/conf
# Provide a mapred link for MR2 hadoop launcher script
ln -fs hadoop ${MAPREDUCE_MR1_DIR}/bin/mapred
# Symlink the native bits
mkdir -p ${MAPREDUCE_MR1_DIR}/lib/native/
ln -s /usr/lib/hadoop/lib/native ${MAPREDUCE_MR1_DIR}/lib/native/${NATIVE_BUILD_STRING}
# C++ examples
cp -r ${BUILD_DIR}/examples-mapreduce1/*/include ${MAPREDUCE_MR1_DIR}
cp -r ${BUILD_DIR}/examples-mapreduce1/*/bin/* ${MAPREDUCE_MR1_DIR}/bin
cp -r ${BUILD_DIR}/examples-mapreduce1/*/lib/* ${MAPREDUCE_MR1_DIR}/lib/native/
# Example confs
cp -r ${BUILD_DIR}/src/hadoop-mapreduce1-project/example-confs ${MAPREDUCE_MR1_DIR}

# lib jars
install -d -m 0755 ${HADOOP_DIR}/lib
cp ${BUILD_DIR}/share/hadoop/common/lib/*.jar ${HADOOP_DIR}/lib
install -d -m 0755 ${MAPREDUCE_DIR}/lib
cp ${BUILD_DIR}/share/hadoop/mapreduce/lib/*.jar ${MAPREDUCE_DIR}/lib
install -d -m 0755 ${HDFS_DIR}/lib 
cp ${BUILD_DIR}/share/hadoop/hdfs/lib/*.jar ${HDFS_DIR}/lib
install -d -m 0755 ${YARN_DIR}/lib
cp ${BUILD_DIR}/share/hadoop/yarn/lib/*.jar ${YARN_DIR}/lib
chmod 644 ${HADOOP_DIR}/lib/*.jar ${MAPREDUCE_DIR}/lib/*.jar ${HDFS_DIR}/lib/*.jar ${YARN_DIR}/lib/*.jar

# Install webapps
cp -ra ${BUILD_DIR}/share/hadoop/hdfs/webapps ${HDFS_DIR}/

# bin
install -d -m 0755 ${HADOOP_DIR}/bin
cp -a ${BUILD_DIR}/bin/{hadoop,rcc,fuse_dfs} ${HADOOP_DIR}/bin
install -d -m 0755 ${HDFS_DIR}/bin
cp -a ${BUILD_DIR}/bin/hdfs ${HDFS_DIR}/bin
install -d -m 0755 ${YARN_DIR}/bin
cp -a ${BUILD_DIR}/bin/{yarn,container-executor} ${YARN_DIR}/bin
install -d -m 0755 ${MAPREDUCE_DIR}/bin
cp -a ${BUILD_DIR}/bin/mapred ${MAPREDUCE_DIR}/bin
cp -a ${BUILD_DIR}/examples/bin/* ${MAPREDUCE_DIR}/bin
# FIXME: MAPREDUCE-3980
cp -a ${BUILD_DIR}/bin/mapred ${YARN_DIR}/bin

# sbin
install -d -m 0755 ${HADOOP_DIR}/sbin
cp -a ${BUILD_DIR}/sbin/{hadoop-daemon,hadoop-daemons,slaves}.sh ${HADOOP_DIR}/sbin
install -d -m 0755 ${HDFS_DIR}/sbin
cp -a ${BUILD_DIR}/sbin/{distribute-exclude,refresh-namenodes}.sh ${HDFS_DIR}/sbin
install -d -m 0755 ${YARN_DIR}/sbin
cp -a ${BUILD_DIR}/sbin/{yarn-daemon,yarn-daemons}.sh ${YARN_DIR}/sbin
install -d -m 0755 ${MAPREDUCE_DIR}/sbin
cp -a ${BUILD_DIR}/sbin/mr-jobhistory-daemon.sh ${MAPREDUCE_DIR}/sbin

# native libs
install -d -m 0755 ${SYSTEM_LIB_DIR}
install -d -m 0755 ${HADOOP_NATIVE_LIB_DIR}
for library in libhdfs.so.0.0.0; do
  cp ${BUILD_DIR}/lib/native/${library} ${SYSTEM_LIB_DIR}/
  ldconfig -vlN ${SYSTEM_LIB_DIR}/${library}
  ln -s ${library} ${SYSTEM_LIB_DIR}/${library/.so.*/}.so
done

install -d -m 0755 ${SYSTEM_INCLUDE_DIR}
cp ${BUILD_DIR}/include/hdfs.h ${SYSTEM_INCLUDE_DIR}/

cp ${BUILD_DIR}/lib/native/*.a ${HADOOP_NATIVE_LIB_DIR}/
for library in `cd ${BUILD_DIR}/lib/native ; ls libsnappy.so.1.* 2>/dev/null` libhadoop.so.1.0.0; do
  cp ${BUILD_DIR}/lib/native/${library} ${HADOOP_NATIVE_LIB_DIR}/
  ldconfig -vlN ${HADOOP_NATIVE_LIB_DIR}/${library}
  ln -s ${library} ${HADOOP_NATIVE_LIB_DIR}/${library/.so.*/}.so
done

# Install fuse wrapper
fuse_wrapper=${BIN_DIR}/hadoop-fuse-dfs
cat > $fuse_wrapper << EOF
#!/bin/bash

/sbin/modprobe fuse

# Autodetect JAVA_HOME if not defined
. /usr/lib/bigtop-utils/bigtop-detect-javahome

export HADOOP_HOME=\${HADOOP_HOME:-${HADOOP_DIR#${PREFIX}}}

if [ -f /etc/default/hadoop-fuse ]
then . /etc/default/hadoop-fuse
fi

export HADOOP_LIBEXEC_DIR=${SYSTEM_LIBEXEC_DIR#${PREFIX}}

if [ "\${LD_LIBRARY_PATH}" = "" ]; then
  export LD_LIBRARY_PATH=/usr/lib
  for f in \`find \${JAVA_HOME}/ -name client -prune -o -name libjvm.so -exec dirname {} \;\`; do
    export LD_LIBRARY_PATH=\$f:\${LD_LIBRARY_PATH}
  done
fi

# Pulls all jars from hadoop client package and conf files from HADOOP_CONF_DIR
for jar in \${HADOOP_HOME}/client/*.jar; do
  CLASSPATH+="\$jar:"
done
CLASSPATH+="\${HADOOP_CONF_DIR:-\${HADOOP_HOME}/etc/hadoop}"


env CLASSPATH="\${CLASSPATH}" \${HADOOP_HOME}/bin/fuse_dfs \$@
EOF

chmod 755 $fuse_wrapper

# Bash tab completion
install -d -m 0755 $BASH_COMPLETION_DIR
install -m 0644 \
  $SOURCE_DIR/hadoop-common-project/hadoop-common/src/contrib/bash-tab-completion/hadoop.sh \
  $BASH_COMPLETION_DIR/hadoop
# install hadoop-0.20 wrapper
for bin_wrapper in hadoop-0.20 ; do
  wrapper=$BIN_DIR/$bin_wrapper
  cat > $wrapper <<EOF
#!/bin/sh

# Autodetect JAVA_HOME if not defined
. /usr/lib/bigtop-utils/bigtop-detect-javahome

export HADOOP_HOME=$INSTALLED_LIB_DIR
export HADOOP_MAPRED_HOME=$INSTALLED_LIB_DIR
export HADOOP_LIBEXEC_DIR=${SYSTEM_LIBEXEC_DIR#${PREFIX}}
export HADOOP_CONF_DIR=/etc/hadoop/conf

exec $INSTALLED_LIB_DIR/bin/hadoop "\$@"
EOF
  chmod 755 $wrapper
done

# conf
install -d -m 0755 $HADOOP_ETC_DIR/conf.empty
cp ${DISTRO_DIR}/conf.empty/mapred-site.xml $HADOOP_ETC_DIR/conf.empty
# workaround for CDH-9780
ln -s conf.empty $HADOOP_ETC_DIR/conf.dist

cp ${BUILD_DIR}/etc/hadoop/* $HADOOP_ETC_DIR/conf.empty
cp $DISTRO_DIR/conf.empty/* $HADOOP_ETC_DIR/conf.empty

# docs
install -d -m 0755 ${DOC_DIR}
cp -r ${BUILD_DIR}/share/doc/* ${DOC_DIR}/

# examples and (MR1)
# FIXME MR1: we should have a better place for MR1 docs
MR1_EXAMPLES=`dirname ${DOC_DIR}`/hadoop-0.20-mapreduce/examples
install -d -m 0755 ${MR1_EXAMPLES}
cp -r ${BUILD_DIR}/src/hadoop-mapreduce1-project/src/examples ${MR1_EXAMPLES}/src
for x in ${MAPREDUCE_MR1_DIR}/*examples*jar ${MAPREDUCE_MR1_DIR}/hadoop-examples.jar ; do
  ln -sf `echo $x | sed -e "s,$PREFIX,,"` ${MR1_EXAMPLES}
done

# LNRC (MR1)
cp ${BUILD_DIR}/share/doc/hadoop-mapreduce1/{LICENSE,NOTICE,README,CHANGES}.txt ${MAPREDUCE_MR1_DIR}

# man pages
mkdir -p $MAN_DIR/man1
gzip -c < $DISTRO_DIR/hadoop.1 > $MAN_DIR/man1/hadoop.1.gz
chmod 644 $MAN_DIR/man1/hadoop.1.gz

# HTTPFS
install -d -m 0755 ${HTTPFS_DIR}/sbin
cp ${BUILD_DIR}/sbin/httpfs.sh ${HTTPFS_DIR}/sbin/
cp -r ${BUILD_DIR}/share/hadoop/httpfs/tomcat/webapps ${HTTPFS_DIR}/
cp -r ${BUILD_DIR}/share/hadoop/httpfs/tomcat/conf ${HTTPFS_DIR}/
chmod 644 ${HTTPFS_DIR}/conf/*
install -d -m 0755 $HTTPFS_ETC_DIR/conf.empty
mv $HADOOP_ETC_DIR/conf.empty/httpfs* $HTTPFS_ETC_DIR/conf.empty
sed -i -e '/<\/configuration>/i\
  <!-- HUE proxy user setting -->\
  <property>\
    <name>httpfs.proxyuser.hue.hosts</name>\
    <value>*</value>\
  </property>\
  <property>\
    <name>httpfs.proxyuser.hue.groups</name>\
    <value>*</value>\
  </property>\
\
  <property>\
    <name>httpfs.hadoop.config.dir</name>\
    <value>/etc/hadoop/conf</value>\
  </property>' $HTTPFS_ETC_DIR/conf.empty/httpfs-site.xml

# Make the pseudo-distributed config
for conf in conf.pseudo ; do
  install -d -m 0755 $HADOOP_ETC_DIR/$conf
  # Overlay the -site files
  (cd $DISTRO_DIR/$conf && tar -cf - .) | (cd $HADOOP_ETC_DIR/$conf && tar -xf -)
done
cp ${BUILD_DIR}/etc/hadoop/log4j.properties $HADOOP_ETC_DIR/conf.pseudo
# MR1
cp -r $HADOOP_ETC_DIR/conf.pseudo $HADOOP_ETC_DIR/conf.pseudo.mr1
rm -f $HADOOP_ETC_DIR/conf.pseudo.mr1/{yarn-site.xml,hadoop-env.sh}
cp ${MAPREDUCE_MR1_DIR}/example-confs/conf.pseudo/mapred-site.xml $HADOOP_ETC_DIR/conf.pseudo.mr1
cat >> $HADOOP_ETC_DIR/conf.pseudo.mr1/README <<__EOT__

Please note, that this particular configuration runs old style MRv1
daemons (jobtracker and tasktracker). If you want to have a pseudo
distributed configuration of YARN (MRv2) uninstall this package and
install hadoop-conf-pseudo instead.
__EOT__

# FIXME: Provide a convenience link for configuration (HADOOP-7939)
install -d -m 0755 ${HADOOP_DIR}/etc
ln -s ${HADOOP_ETC_DIR##${PREFIX}}/conf ${HADOOP_DIR}/etc/hadoop
install -d -m 0755 ${YARN_DIR}/etc
ln -s ${HADOOP_ETC_DIR##${PREFIX}}/conf ${YARN_DIR}/etc/hadoop

# Create log, var and lib
install -d -m 0755 $PREFIX/var/{log,run,lib}/hadoop-hdfs
install -d -m 0755 $PREFIX/var/{log,run,lib}/hadoop-yarn
install -d -m 0755 $PREFIX/var/{log,run,lib}/hadoop-mapreduce
install -d -m 0755 $PREFIX/var/{log,run,lib}/hadoop-0.20-mapreduce

# Remove all source and create version-less symlinks to offer integration point with other projects
# FIXME MR1: we should probably unify the versions to begin with
MR1_VERSION=`grep '^version' ${SOURCE_DIR}/hadoop-mapreduce1-project/build.properties | cut -f2 -d=`
for DIR in ${HADOOP_DIR} ${HDFS_DIR} ${YARN_DIR} ${MAPREDUCE_DIR} ${HTTPFS_DIR} \
  ${MAPREDUCE_MR1_DIR} ${MAPREDUCE_MR1_DIR}/contrib/*; do
  (cd $DIR &&
   rm -fv *-sources.jar
   rm -fv lib/hadoop-*.jar
   for j in hadoop-*.jar; do
     if [[ $j =~ hadoop-(.*)-${HADOOP_VERSION}.jar ]] || [[ $j =~ hadoop-(.*)-${MR1_VERSION}.jar ]] ; then
       name=${BASH_REMATCH[1]}
       ln -s $j hadoop-$name.jar
     fi
   done)
done

# CDH3/4 MR1 specific: we make fair scheduler available by default
cp ${MAPREDUCE_MR1_DIR}/contrib/fairscheduler/hadoop-fairscheduler*.jar ${MAPREDUCE_MR1_DIR}/lib

# Now create a client installation area full of symlinks
install -d -m 0755 ${CLIENT_DIR}
for file in `cat ${BUILD_DIR}/hadoop-client.list` ; do
  for dir in ${HADOOP_DIR}/{lib,} ${HDFS_DIR}/{lib,} ${YARN_DIR}/{lib,} ${MAPREDUCE_DIR}/{lib,} ; do
    [ -e $dir/$file ] && \
    ln -fs ${dir#$PREFIX}/$file ${CLIENT_DIR}/${file} && \
    ln -fs ${dir#$PREFIX}/$file ${CLIENT_DIR}/${file/-[[:digit:]]*/.jar} && \
    continue 2
  done
  exit 1
done

# Now create a MR1 client installation area full of symlinks
install -d -m 0755 ${CLIENT_MR1_DIR}
for file in `cat ${BUILD_DIR}/hadoop-mr1-client.list` ; do
  for dir in ${HADOOP_DIR}/{lib,} ${HDFS_DIR}/{lib,} ${MAPREDUCE_MR1_DIR}/{lib,} ; do
    [ -e $dir/$file ] && \
    ln -fs ${dir#$PREFIX}/$file ${CLIENT_MR1_DIR}/$file && \
    ln -fs ${dir#$PREFIX}/$file ${CLIENT_MR1_DIR}/${file/-[[:digit:]]*/.jar} && \
    continue 2
  done
  exit 1
done

# Cloudera specific
for map in hadoop_${HADOOP_DIR} hadoop-hdfs_${HDFS_DIR} hadoop-yarn_${YARN_DIR} \
           hadoop-mapreduce_${MAPREDUCE_DIR} hadoop-0.20-mapreduce_${MAPREDUCE_MR1_DIR} \
           hadoop-httpfs_${HTTPFS_DIR} ; do
  dir=${map#*_}/cloudera
  install -d -m 0755 $dir
  grep -v 'cloudera.pkg.name=' cloudera/cdh_version.properties > $dir/cdh_version.properties
  echo "cloudera.pkg.name=${map%%_*}" >> $dir/cdh_version.properties
done
