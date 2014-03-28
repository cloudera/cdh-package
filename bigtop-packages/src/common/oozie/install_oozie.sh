#!/bin/bash
set -ex

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
#

usage() {
  echo "
usage: $0 <options>
  Required not-so-options:
     --extra-dir=DIR    path to Bigtop distribution files
     --build-dir=DIR    path to Bigtop distribution files
     --server-dir=DIR   path to server package root
     --client-dir=DIR   path to the client package root
     --initd-dir=DIR    path to the server init.d directory

  Optional options:
     --docs-dir=DIR     path to the documentation root
  "
  exit 1
}

OPTS=$(getopt \
  -n $0 \
  -o '' \
  -l 'extra-dir:' \
  -l 'build-dir:' \
  -l 'server-dir:' \
  -l 'client-dir:' \
  -l 'docs-dir:' \
  -l 'initd-dir:' \
  -l 'conf-dir:' \
  -- "$@")

if [ $? != 0 ] ; then
    usage
fi

eval set -- "$OPTS"
while true ; do
    case "$1" in
        --extra-dir)
        EXTRA_DIR=$2 ; shift 2
        ;;
        --build-dir)
        BUILD_DIR=$2 ; shift 2
        ;;
        --server-dir)
        SERVER_PREFIX=$2 ; shift 2
        ;;
        --client-dir)
        CLIENT_PREFIX=$2 ; shift 2
        ;;
        --docs-dir)
        DOC_DIR=$2 ; shift 2
        ;;
        --initd-dir)
        INITD_DIR=$2 ; shift 2
        ;;
        --conf-dir)
        CONF_DIR=$2 ; shift 2
        ;;
        --)
        shift; break
        ;;
        *)
        echo "Unknown option: $1"
        usage
        ;;
    esac
done

for var in BUILD_DIR SERVER_PREFIX CLIENT_PREFIX; do
  if [ -z "$(eval "echo \$$var")" ]; then
    echo Missing param: $var
    usage
  fi
done

if [ ! -d "${BUILD_DIR}" ]; then
  echo "Build directory does not exist: ${BUILD_DIR}"
  exit 1
fi

## Install client image first
CLIENT_LIB_DIR=${CLIENT_PREFIX}/usr/lib/oozie
MAN_DIR=${CLIENT_PREFIX}/usr/share/man/man1
DOC_DIR=${DOC_DIR:-$CLIENT_PREFIX/usr/share/doc/oozie}
BIN_DIR=${CLIENT_PREFIX}/usr/bin

install -d -m 0755 ${CLIENT_LIB_DIR}
install -d -m 0755 ${CLIENT_LIB_DIR}/bin
cp -R ${BUILD_DIR}/bin/oozie ${CLIENT_LIB_DIR}/bin
cp -R ${BUILD_DIR}/lib ${CLIENT_LIB_DIR}
install -d -m 0755 ${DOC_DIR}
cp -R ${BUILD_DIR}/LICENSE.txt ${DOC_DIR}
cp -R ${BUILD_DIR}/NOTICE.txt ${DOC_DIR}
cp -R ${BUILD_DIR}/oozie-examples.tar.gz ${DOC_DIR}
cp -R ${BUILD_DIR}/README.txt ${DOC_DIR}
cp -R ${BUILD_DIR}/release-log.txt ${DOC_DIR}
[ -f ${BUILD_DIR}/PATCH.txt ] && cp ${BUILD_DIR}/PATCH.txt ${DOC_DIR}
cp -R ${BUILD_DIR}/docs/* ${DOC_DIR}
rm -rf ${DOC_DIR}/target
install -d -m 0755 ${MAN_DIR}
gzip -c ${EXTRA_DIR}/oozie.1 > ${MAN_DIR}/oozie.1.gz

# Create the /usr/bin/oozie wrapper
install -d -m 0755 $BIN_DIR
cat > ${BIN_DIR}/oozie <<EOF
#!/bin/bash
#
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

# Autodetect JAVA_HOME if not defined
. /usr/lib/bigtop-utils/bigtop-detect-javahome

exec /usr/lib/oozie/bin/oozie "\$@"
EOF
chmod 755 ${BIN_DIR}/oozie

[ -d ${SERVER_PREFIX}/usr/bin ] || install -d -m 0755 ${SERVER_PREFIX}/usr/bin
cat > ${SERVER_PREFIX}/usr/bin/oozie-setup <<'EOF'
#!/bin/bash
#
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

# Autodetect JAVA_HOME if not defined
. /usr/lib/bigtop-utils/bigtop-detect-javahome

if [ "$1" == "prepare-war" ]; then
    echo "The prepare-war command is not supported in packages."
    exit 1
fi

COMMAND="cd ~/ && /usr/lib/oozie/bin/oozie-setup.sh $@"
su -s /bin/bash -c "$COMMAND" oozie
EOF
chmod 755 ${SERVER_PREFIX}/usr/bin/oozie-setup

## Install server image
SERVER_LIB_DIR=${SERVER_PREFIX}/usr/lib/oozie
CONF_DIR=${CONF_DIR:-"${SERVER_PREFIX}/etc/oozie/conf.dist"}
ETC_DIR=${SERVER_PREFIX}/etc/oozie
DATA_DIR=${SERVER_PREFIX}/var/lib/oozie

install -d -m 0755 ${SERVER_LIB_DIR}
install -d -m 0755 ${SERVER_LIB_DIR}/bin
install -d -m 0755 ${DATA_DIR}
install -d -m 0755 ${DATA_DIR}/work
for file in oozie-setup.sh ooziedb.sh oozied.sh oozie-sys.sh ; do
  cp ${BUILD_DIR}/bin/$file ${SERVER_LIB_DIR}/bin
done

install -d -m 0755 ${CONF_DIR}
cp -r ${BUILD_DIR}/conf/* ${CONF_DIR}
sed -i -e '/oozie.service.HadoopAccessorService.hadoop.configurations/,/<\/property>/s#<value>\*=hadoop-conf</value>#<value>*=/etc/hadoop/conf</value>#g' \
          ${CONF_DIR}/oozie-site.xml
cp ${EXTRA_DIR}/oozie-env.sh ${CONF_DIR}
install -d -m 0755 ${CONF_DIR}/action-conf
cp ${EXTRA_DIR}/hive.xml ${CONF_DIR}/action-conf
if [ "${INITD_DIR}" != "" ]; then
  install -d -m 0755 ${INITD_DIR}
  cp -R ${EXTRA_DIR}/oozie.init ${INITD_DIR}/oozie
  chmod 755 ${INITD_DIR}/oozie
fi
mv ${BUILD_DIR}/oozie-sharelib-*-yarn.tar.gz ${SERVER_LIB_DIR}/oozie-sharelib-yarn.tar.gz
mv ${BUILD_DIR}/oozie-sharelib-*.tar.gz ${SERVER_LIB_DIR}/oozie-sharelib-mr1.tar.gz
ln -s oozie-sharelib-yarn.tar.gz ${SERVER_LIB_DIR}/oozie-sharelib.tar.gz
ln -s -f /etc/oozie/conf/oozie-env.sh ${SERVER_LIB_DIR}/bin

cp -R ${BUILD_DIR}/oozie-server/webapps ${SERVER_LIB_DIR}/webapps

# Unpack oozie.war some place reasonable
OOZIE_WEBAPP=${SERVER_LIB_DIR}/webapps/oozie
mkdir ${OOZIE_WEBAPP}
unzip -d ${OOZIE_WEBAPP} ${BUILD_DIR}/oozie.war
mv -f ${OOZIE_WEBAPP}/WEB-INF/lib ${SERVER_LIB_DIR}/libserver
touch ${SERVER_LIB_DIR}/webapps/oozie.war

install -m 0755 ${EXTRA_DIR}/tomcat-deployment.sh ${SERVER_LIB_DIR}/tomcat-deployment.sh

HTTP_DIRECTORY=${ETC_DIR}/tomcat-conf.http
install -d -m 0755 ${HTTP_DIRECTORY}
cp -R ${BUILD_DIR}/oozie-server/conf ${HTTP_DIRECTORY}/conf
cp ${EXTRA_DIR}/context.xml ${HTTP_DIRECTORY}/conf/
cp ${EXTRA_DIR}/catalina.properties ${HTTP_DIRECTORY}/conf/
install -d -m 0755 ${HTTP_DIRECTORY}/WEB-INF
mv ${SERVER_LIB_DIR}/webapps/oozie/WEB-INF/*.xml ${HTTP_DIRECTORY}/WEB-INF

HTTPS_DIRECTORY=${ETC_DIR}/tomcat-conf.https
cp -r ${HTTP_DIRECTORY} ${HTTPS_DIRECTORY}
cp ${HTTPS_DIRECTORY}/conf/ssl/ssl-server.xml ${HTTPS_DIRECTORY}/conf/server.xml
cp ${BUILD_DIR}/oozie-server/conf/ssl/ssl-web.xml ${HTTPS_DIRECTORY}/WEB-INF/web.xml

HTTP_MR1_DIRECTORY=${ETC_DIR}/tomcat-conf.http.mr1
cp -r ${HTTP_DIRECTORY} ${HTTP_MR1_DIRECTORY}
cp -f ${EXTRA_DIR}/catalina.properties.mr1 ${HTTP_MR1_DIRECTORY}/conf/catalina.properties

HTTPS_MR1_DIRECTORY=${ETC_DIR}/tomcat-conf.https.mr1
cp -r ${HTTPS_DIRECTORY} ${HTTPS_MR1_DIRECTORY}
cp -f ${EXTRA_DIR}/catalina.properties.mr1 ${HTTP_MR1_DIRECTORY}/conf/catalina.properties

# Create all the jars needed for tools execution
install -d -m 0755 ${SERVER_LIB_DIR}/libtools
for i in `cd ${BUILD_DIR}/libtools ; ls *` ; do
  if [ -e ${SERVER_LIB_DIR}/libserver/$i ] ; then
    ln -s ../libserver/$i ${SERVER_LIB_DIR}/libtools/$i
  else
    cp ${BUILD_DIR}/libtools/$i ${SERVER_LIB_DIR}/libtools/$i
  fi
done

# Provide a convenience symlink to be more consistent with tarball deployment
ln -s ${DATA_DIR#${SERVER_PREFIX}} ${SERVER_LIB_DIR}/libext

# Cloudera specific
install -d -m 0755 ${SERVER_LIB_DIR}/cloudera
cp ${BUILD_DIR}/cloudera/cdh_version.properties ${SERVER_LIB_DIR}/cloudera/

# Replace every Avro or Parquet jar with a symlink to the versionless symlinks in our distribution
# This regex matches upstream versions, plus CDH versions, betas and snapshots if they are present
versions='s#-[0-9].[0-9].[0-9]\(-cdh[0-9\-\.]*[0-9]\)\?\(-beta-[0-9]\+\)\?\(-SNAPSHOT\)\?##'
timestamps='s#-[0-9]\{8\}\.[0-9]\{6\}-[0-9]\{1,2\}##'
for dir in ${SERVER_LIB_DIR}/libtools ${SERVER_LIB_DIR}/libserver ; do
    for old_jar in `find $dir -maxdepth 1 -name avro*.jar -o -name parquet*.jar | grep -v 'cassandra'`; do
        base_jar=`basename $old_jar`; new_jar=`echo $base_jar | sed -e $versions | sed -e $timestamps`
        rm $old_jar && ln -fs /usr/lib/${base_jar/[-.]*/}/$new_jar $dir/
    done
done

