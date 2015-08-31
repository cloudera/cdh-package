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
     --distro-dir=DIR            path to distro specific files (debian/RPM)
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
  -l 'distro-dir:' \
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
        --distro-dir)
        DISTRO_DIR=$2 ; shift 2
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

for var in PREFIX BUILD_DIR DISTRO_DIR ; do
  if [ -z "$(eval "echo \$$var")" ]; then
    echo Missing param: $var
    usage
  fi
done

. ${DISTRO_DIR}/packaging_functions.sh

MAN_DIR=${MAN_DIR:-/usr/share/man/man1}
DOC_DIR=${DOC_DIR:-/usr/share/doc/solr}
LIB_DIR=${LIB_DIR:-/usr/lib/solr}
INSTALLED_LIB_DIR=${INSTALLED_LIB_DIR:-/usr/lib/solr}
EXAMPLES_DIR=${EXAMPLES_DIR:-$DOC_DIR/examples}
BIN_DIR=${BIN_DIR:-/usr/bin}
CONF_DIR=${CONF_DIR:-/etc/solr/conf}
DEFAULT_DIR=${ETC_DIR:-/etc/default}

VAR_DIR=$PREFIX/var

install -d -m 0755 $PREFIX/$LIB_DIR
cp -ra ${BUILD_DIR}/dist/*.*ar $PREFIX/$LIB_DIR
cp -ra ${BUILD_DIR}/dist/solrj-lib $PREFIX/$LIB_DIR/lib
cp -ra ${BUILD_DIR}/example/solr/collection1/conf $PREFIX/$LIB_DIR/coreconfig-template
cp -fa cloudera/solrconfig.xml cloudera/solrconfig.xml.secure cloudera/schema.xml $PREFIX/$LIB_DIR/coreconfig-template
mkdir $PREFIX/$LIB_DIR/coreconfig-schemaless-template
cp -fa cloudera/solrconfig.xml.schemaless cloudera/solrconfig.xml.schemaless.secure cloudera/schema.xml.schemaless  $PREFIX/$LIB_DIR/coreconfig-schemaless-template

for DIRNAME in predefinedTemplate managedTemplate schemalessTemplate predefinedTemplateSecure managedTemplateSecure schemalessTemplateSecure
do
  cp -ra ${BUILD_DIR}/example/solr/collection1/conf $PREFIX/$LIB_DIR/$DIRNAME
  cp -fa cloudera/configsetprops.json $PREFIX/$LIB_DIR/$DIRNAME
done

DIRNAME=predefinedTemplate
cp -fa cloudera/solrconfig.xml $PREFIX/$LIB_DIR/$DIRNAME/solrconfig.xml
cp -fa cloudera/schema.xml $PREFIX/$LIB_DIR/$DIRNAME/schema.xml

DIRNAME=managedTemplate
cp -fa cloudera/solrconfig.xml.managed $PREFIX/$LIB_DIR/$DIRNAME/solrconfig.xml
cp -fa cloudera/schema.xml.managed $PREFIX/$LIB_DIR/$DIRNAME/schema.xml

DIRNAME=schemalessTemplate
cp -fa cloudera/solrconfig.xml.schemaless $PREFIX/$LIB_DIR/$DIRNAME/solrconfig.xml
cp -fa cloudera/schema.xml.schemaless $PREFIX/$LIB_DIR/$DIRNAME/schema.xml

DIRNAME=predefinedTemplateSecure
cp -fa cloudera/solrconfig.xml.secure $PREFIX/$LIB_DIR/$DIRNAME/solrconfig.xml
cp -fa cloudera/schema.xml $PREFIX/$LIB_DIR/$DIRNAME/schema.xml

DIRNAME=managedTemplateSecure
cp -fa cloudera/solrconfig.xml.managed.secure $PREFIX/$LIB_DIR/$DIRNAME/solrconfig.xml
cp -fa cloudera/schema.xml.managed $PREFIX/$LIB_DIR/$DIRNAME/schema.xml

DIRNAME=schemalessTemplateSecure
cp -fa cloudera/solrconfig.xml.schemaless.secure $PREFIX/$LIB_DIR/$DIRNAME/solrconfig.xml
cp -fa cloudera/schema.xml.schemaless $PREFIX/$LIB_DIR/$DIRNAME/schema.xml

cp -ra cloudera/clusterconfig $PREFIX/$LIB_DIR/clusterconfig

install -d -m 0755 $PREFIX/$LIB_DIR/contrib
cp -ra ${BUILD_DIR}/contrib/velocity $PREFIX/$LIB_DIR/contrib

# Copy in the configuration files
install -d -m 0755 $PREFIX/$DEFAULT_DIR
cp $DISTRO_DIR/solr.default $PREFIX/$DEFAULT_DIR/solr

install -d -m 0755 $PREFIX/${CONF_DIR}.dist
cp -ra ${BUILD_DIR}/example/solr/* $PREFIX/${CONF_DIR}.dist

install -d -m 0755 $PREFIX/$LIB_DIR/webapps/solr
(cd $PREFIX/$LIB_DIR/webapps/solr ; jar xf ../../*.war)

cp ${BUILD_DIR}/example/lib/ext/*.jar $PREFIX/$LIB_DIR/webapps/solr/WEB-INF/lib/
cp ${BUILD_DIR}/contrib/sentry-handlers/lib/*.jar $PREFIX/$LIB_DIR/webapps/solr/WEB-INF/lib/

install -d -m 0755 $PREFIX/$LIB_DIR/webapps/ROOT
cat > $PREFIX/$LIB_DIR/webapps/ROOT/index.html <<__EOT__
<html><head><meta http-equiv="refresh" content="0;url=./solr"></head><body><a href="/solr">Solr Console</a></body></html>
__EOT__

install -m 0755 ${DISTRO_DIR}/tomcat-deployment.sh ${PREFIX}/${LIB_DIR}/tomcat-deployment.sh

HTTP_DIRECTORY=${PREFIX}/etc/solr/tomcat-conf.dist
install -d -m 0755 ${HTTP_DIRECTORY}/conf
cp $DISTRO_DIR/web.xml ${HTTP_DIRECTORY}/conf
cp $DISTRO_DIR/server.xml ${HTTP_DIRECTORY}/conf
cp $DISTRO_DIR/logging.properties ${HTTP_DIRECTORY}/conf
install -d -m 0755 ${HTTP_DIRECTORY}/WEB-INF
mv $PREFIX/$LIB_DIR/webapps/solr/WEB-INF/*.xml ${HTTP_DIRECTORY}/WEB-INF/ || :

HTTPS_DIRECTORY=${PREFIX}/etc/solr/tomcat-conf.https
cp -r ${HTTP_DIRECTORY} ${HTTPS_DIRECTORY}
cp ${DISTRO_DIR}/server-ssl.xml ${HTTPS_DIRECTORY}/conf/server.xml

cp -ra ${BUILD_DIR}/dist/*.*ar $PREFIX/$LIB_DIR
cp -ra ${BUILD_DIR}/dist/solrj-lib $PREFIX/$LIB_DIR/lib

# The cloud-scripts folder contains solrctl.sh and zkcli.sh presently.
install -d -m 0755 $PREFIX/$LIB_DIR/bin
cp -a ${BUILD_DIR}/example/scripts/cloud-scripts/*.sh $PREFIX/$LIB_DIR/bin
sed -i -e 's#/../solr-webapp/webapp/WEB-INF/lib/#/../webapps/solr/WEB-INF/lib/#' $PREFIX/$LIB_DIR/bin/zkcli.sh
chmod 755 $PREFIX/$LIB_DIR/bin/*

install -d -m 0755 $PREFIX/$DOC_DIR
cp -a  ${BUILD_DIR}/*.txt $PREFIX/$DOC_DIR
cp -ra ${BUILD_DIR}/docs/* $PREFIX/$DOC_DIR
cp -ra ${BUILD_DIR}/example/ $PREFIX/$DOC_DIR/

# Copy in the wrapper
cat > $PREFIX/$LIB_DIR/bin/solrd <<'EOF'
#!/bin/bash

BIGTOP_DEFAULTS_DIR=${BIGTOP_DEFAULTS_DIR-/etc/default}
[ -n "${BIGTOP_DEFAULTS_DIR}" -a -r ${BIGTOP_DEFAULTS_DIR}/solr ] && . ${BIGTOP_DEFAULTS_DIR}/solr

# Autodetect JAVA_HOME if not defined
if [ -e /usr/lib/bigtop-utils/bigtop-detect-javahome ]; then
  . /usr/lib/bigtop-utils/bigtop-detect-javahome
fi

# resolve links - $0 may be a softlink
PRG="${BASH_SOURCE[0]}"

while [ -h "${PRG}" ]; do
  ls=`ls -ld "${PRG}"`
  link=`expr "$ls" : '.*-> \(.*\)$'`
  if expr "$link" : '/.*' > /dev/null; then
    PRG="$link"
  else
    PRG=`dirname "${PRG}"`/"$link"
  fi
done

BASEDIR=`dirname ${PRG}`
BASEDIR=`cd ${BASEDIR}/..;pwd`

SOLR_PORT=${SOLR_PORT:-8983}
SOLR_ADMIN_PORT=${SOLR_ADMIN_PORT:-8984}
SOLR_MAX_CONNECTOR_THREAD=${SOLR_MAX_CONNECTOR_THREAD:-10000}
SOLR_LOG=${SOLR_LOG:-/var/log/solr}
SOLR_HOME=${SOLR_HOME:-/var/lib/solr}
SOLR_LOG4J_CONFIG=${SOLR_LOG4J_CONFIG:-/etc/solr/conf/log4j.properties}

export CATALINA_HOME=${CATALINA_HOME:-$BASEDIR/../bigtop-tomcat}
export CATALINA_BASE=/var/lib/solr/tomcat-deployment

export CATALINA_TMPDIR=${SOLR_DATA:-/var/lib/solr/}
export CATALINA_PID=${SOLR_RUN:-/var/run/solr}/solr.pid
export CATALINA_OUT=${SOLR_LOG:-/var/log/solr}/solr.out

die() {
  echo "$@" >&2
  exit 1
}

# Preflight checks:
# 1. We are only supporting SolrCloud mode
if [ -z "$SOLR_ZK_ENSEMBLE" ] ; then
  die "Error: SOLR_ZK_ENSEMBLE is not set in /etc/default/solr"
fi

CATALINA_OPTS="${CATALINA_OPTS} -DzkHost=${SOLR_ZK_ENSEMBLE} -Dsolr.solrxml.location=zookeeper"

if [ -n "$SOLR_HDFS_HOME" ] ; then
  CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.hdfs.home=${SOLR_HDFS_HOME}"
fi

if [ -n "$SOLR_HDFS_CONFIG" ] ; then
  CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.hdfs.confdir=${SOLR_HDFS_CONFIG}"
fi

if [ "$SOLR_KERBEROS_ENABLED" == "true" ] ; then
  CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.hdfs.security.kerberos.enabled=${SOLR_KERBEROS_ENABLED}"
fi

if [ -n "$SOLR_KERBEROS_KEYTAB" ] ; then
  CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.hdfs.security.kerberos.keytabfile=${SOLR_KERBEROS_KEYTAB}"
fi

if [ -n "$SOLR_KERBEROS_PRINCIPAL" ] ; then
  CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.hdfs.security.kerberos.principal=${SOLR_KERBEROS_PRINCIPAL}"
fi

if [ -n "$SOLR_AUTHENTICATION_TYPE" ] ; then
  CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.authentication.type=${SOLR_AUTHENTICATION_TYPE}"
fi

if [ -n "$SOLR_ZKACL_PROVIDER" ] ; then
  CATALINA_OPTS="${CATALINA_OPTS} -DzkACLProvider=${SOLR_ZKACL_PROVIDER}"
fi

if [ -n "$SOLR_AUTHENTICATION_KERBEROS_KEYTAB" ] ; then
  CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.authentication.kerberos.keytab=${SOLR_AUTHENTICATION_KERBEROS_KEYTAB}"
fi

if [ -n "$SOLR_AUTHENTICATION_KERBEROS_PRINCIPAL" ] ; then
  CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.authentication.kerberos.principal=${SOLR_AUTHENTICATION_KERBEROS_PRINCIPAL}"
fi

if [ -n "$SOLR_AUTHENTICATION_KERBEROS_NAME_RULES" ] ; then
  CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.authentication.kerberos.name.rules=${SOLR_AUTHENTICATION_KERBEROS_NAME_RULES}"
fi

if [ -n "$SOLR_AUTHENTICATION_SIMPLE_ALLOW_ANON" ] ; then
  CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.authentication.simple.anonymous.allowed=${SOLR_AUTHENTICATION_SIMPLE_ALLOW_ANON}"
fi

if [ -n "$SOLR_AUTHENTICATION_JAAS_CONF" ] ; then
  CATALINA_OPTS="${CATALINA_OPTS} -Djava.security.auth.login.config=${SOLR_AUTHENTICATION_JAAS_CONF}"
fi

if [ -n "$SOLR_SECURITY_ALLOWED_PROXYUSERS" ] ; then
  old_IFS=${IFS}
  IFS=","
  for user in $SOLR_SECURITY_ALLOWED_PROXYUSERS
    do
      hostsVar="SOLR_SECURITY_PROXYUSER_"$user"_HOSTS"
      eval hostsVal=\$$hostsVar
      if [ -n "$hostsVal" ] ; then
        CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.security.proxyuser.${user}.hosts=${hostsVal}"
      fi
      groupsVar="SOLR_SECURITY_PROXYUSER_"$user"_GROUPS"
      eval groupsVal=\$$groupsVar
      if [ -n "$groupsVal" ] ; then
        CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.security.proxyuser.${user}.groups=${groupsVal}"
      fi
    done
  IFS=${old_IFS}
fi

if [ -n "$SOLR_AUTHENTICATION_LDAP_PROVIDER_URL" ] ; then
  CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.authentication.ldap.providerurl=${SOLR_AUTHENTICATION_LDAP_PROVIDER_URL}"
fi

if [ -n "$SOLR_AUTHENTICATION_LDAP_BASE_DN" ] ; then
  CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.authentication.ldap.basedn=${SOLR_AUTHENTICATION_LDAP_BASE_DN}"
fi

if [ -n "$SOLR_AUTHENTICATION_LDAP_BIND_DOMAIN" ] ; then
  CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.authentication.ldap.binddomain=${SOLR_AUTHENTICATION_LDAP_BIND_DOMAIN}"
fi

if [ -n "$SOLR_AUTHENTICATION_LDAP_ENABLE_START_TLS" ] ; then
  CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.authentication.ldap.enablestarttls=${SOLR_AUTHENTICATION_LDAP_ENABLE_START_TLS}"
fi

if [ -n "$SOLR_AUTHENTICATION_HTTP_SCHEMES" ] ; then
  CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.authentication.multi-scheme-auth-handler.schemes=${SOLR_AUTHENTICATION_HTTP_SCHEMES}"

  if [ -n "$SOLR_AUTHENTICATION_HTTP_DELEGATION_MGMT_SCHEMES" ] ; then
    CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.authentication.multi-scheme-auth-handler.delegation.schemes=${SOLR_AUTHENTICATION_HTTP_DELEGATION_MGMT_SCHEMES}"
  fi

  if [ -n "$SOLR_AUTHENTICATION_HTTP_BASIC_HANDLER" ] ; then
    CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.authentication.multi-scheme-auth-handler.schemes.basic.handler=${SOLR_AUTHENTICATION_HTTP_BASIC_HANDLER}"
  fi

  if [ -n "$SOLR_AUTHENTICATION_HTTP_NEGOTIATE_HANDLER" ] ; then
    CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.authentication.multi-scheme-auth-handler.schemes.negotiate.handler=${SOLR_AUTHENTICATION_HTTP_NEGOTIATE_HANDLER}"
  fi
fi

# FIXME: we need to set this because of the jetty-centric default solr.xml
CATALINA_OPTS="${CATALINA_OPTS} -Dhost=$HOSTNAME -Djetty.port=$SOLR_PORT"

export CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.host=$HOSTNAME
                                        -Dsolr.port=$SOLR_PORT
                                        -Dlog4j.configuration=file://$SOLR_LOG4J_CONFIG
                                        -Dsolr.log=$SOLR_LOG
                                        -Dsolr.admin.port=$SOLR_ADMIN_PORT
                                        -Dsolr.max.connector.thread=$SOLR_MAX_CONNECTOR_THREAD
                                        -Dsolr.solr.home=$SOLR_HOME"

if [ -n "${SOLR_KEYSTORE_PATH}" ]; then
  export CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.keystore.path=${SOLR_KEYSTORE_PATH}"
fi
if [ -n "${SOLR_KEYSTORE_PASSWORD}" ]; then
  export CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.keystore.password=${SOLR_KEYSTORE_PASSWORD}"
fi
if [ -n "${SOLR_TRUSTSTORE_PATH}" ]; then
  CATALINA_OPTS="${CATALINA_OPTS} -Djavax.net.ssl.trustStore=${SOLR_TRUSTSTORE_PATH}"
fi
if [ -n "${SOLR_TRUSTSTORE_PASSWORD}" ]; then
  CATALINA_OPTS="${CATALINA_OPTS} -Djavax.net.ssl.trustStorePassword=${SOLR_TRUSTSTORE_PASSWORD}"
fi

if [ -n "$SOLR_AUTHORIZATION_SENTRY_SITE" ] ; then
  export CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.authorization.sentry.site=${SOLR_AUTHORIZATION_SENTRY_SITE}"
fi

if [ -n "$SOLR_AUTHORIZATION_SUPERUSER" ] ; then
  export CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.authorization.superuser=${SOLR_AUTHORIZATION_SUPERUSER}"
fi

if [ -n "$ZK_SASL_CLIENT_USERNAME" ] ; then
  export CATALINA_OPTS="${CATALINA_OPTS} -Dzookeeper.sasl.client.username=${ZK_SASL_CLIENT_USERNAME}"
fi

#  FIXME: for some reason catalina doesn't use CATALINA_OPTS for stop action
#        and thus doesn't know the admin port
if [ "$1" = "stop" ] ; then
    export JAVA_OPTS="$CATALINA_OPTS"
fi


if [ -x /usr/lib/bigtop-utils/bigtop-monitor-service ]; then
if ([ "$1" = "start" -o "$1" = "run" ]) && [ -n "$SOLRD_WATCHDOG_TIMEOUT" ] ; then
  /usr/lib/bigtop-utils/bigtop-monitor-service $SOLRD_WATCHDOG_TIMEOUT $$
fi
fi

exec ${CATALINA_HOME}/bin/catalina.sh "$@"
EOF
chmod 755 $PREFIX/$LIB_DIR/bin/solrd

# Wrapper script placed under /usr/bin. Invokes $INSTALLED_LIB_DIR/bin/solrctl.sh.
install -d -m 0755 $PREFIX/$BIN_DIR
cat > $PREFIX/$BIN_DIR/solrctl <<EOF
#!/bin/bash

# Autodetect JAVA_HOME if not defined
. /usr/lib/bigtop-utils/bigtop-detect-javahome

export SOLR_HOME=${SOLR_HOME:-/usr/lib/solr/}
export SOLR_DEFAULTS=${SOLR_DEFAULTS:-/etc/default/solr}

exec $INSTALLED_LIB_DIR/bin/solrctl.sh "\$@"

EOF
chmod 755 $PREFIX/$BIN_DIR/solrctl

# precreating /var layout
install -d -m 0755 $VAR_DIR/log/solr
install -d -m 0755 $VAR_DIR/run/solr
install -d -m 0755 $VAR_DIR/lib/solr

# Cloudera specific
install -d -m 0755 $PREFIX/$LIB_DIR/cloudera
cp cloudera/cdh_version.properties $PREFIX/$LIB_DIR/cloudera/

internal_versionless_symlinks \
    ${PREFIX}/${LIB_DIR}/*.jar \
    ${PREFIX}/${LIB_DIR}/webapps/solr/WEB-INF/lib/lucene*.jar \
    ${PREFIX}/${LIB_DIR}/webapps/solr/WEB-INF/lib/solr*.jar

external_versionless_symlinks 'search solr lucene' \
    ${PREFIX}/${LIB_DIR}/lib \
    ${PREFIX}/${LIB_DIR}/lib/solrj-lib \
    ${PREFIX}/${LIB_DIR}/webapps/solr/WEB-INF/lib

