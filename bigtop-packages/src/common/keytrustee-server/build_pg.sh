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

#This script downloads Postgres from the Cloudera artifactory and if
#we do not find it there, rebuilds it from source.  It then copies
#the built tarball to $WORKSPACE which is where do-component-build expects 
#to find it

#Postgres version needed by the keytrustee parcel
PG_VERSION=9.3.6
PG_HOME=opt/postgres/9.3/

#Location of Postgres in Cloudera maven repo
#This should normally be set to PG_VERSION but you can change it for testing purposes
CLOUDERA_PG_VERSION=$PG_VERSION


TARGET_DIR=`pwd`
#Needed for determining tarball name
if [ -z $dist ] ; then
    echo "Variable dist undefined, exiting"
    exit 1
fi
ARCH=$(uname -i)

#Classifier name in the maven repo
PG_CLASSIFIER=$dist.$ARCH

#Filename extension for Postgres tarball in our maven repo
EXT=".tar"

#Name of tarball in our maven repository
PG_FILENAME=postgresql-$CLOUDERA_PG_VERSION-${PG_CLASSIFIER}$EXT
PG_NAMESPACE=com.cloudera.postgres
MVN_ARTIFACT_ID=postgresql
MVN_NAMESPACE=`echo $PG_NAMESPACE | sed 's/\./\//g'`
MVN_BASEURL=http://maven.jenkins.cloudera.com:8081/artifactory/cdh-staging-local/

#The url for postgres will be something like http://maven.jenkins.cloudera.com:8081/artifactory/cdh-staging-local//com/cloudera/postgres/postgresql/8.3.6/
MVN_FULLURL=$MVN_BASEURL/$MVN_NAMESPACE/$MVN_ARTIFACT_ID/$CLOUDERA_PG_VERSION/$PG_FILENAME

if wget $MVN_FULLURL ; then
     echo "Downloaded postgres successfully, exiting"
     exit 0
else
    WGET_STATUS=$?
    if [ $WGET_STATUS -eq 8 ] ; then
        #URL to fetch source tarball from if we need to build Postgres
        PG_URL=https://ftp.postgresql.org/pub/source/v$PG_VERSION
        PG_SOURCE_FILENAME=postgresql-$PG_VERSION

        cd `mktemp -d`
        wget $PG_URL/$PG_SOURCE_FILENAME.tar.gz
        gunzip $PG_SOURCE_FILENAME.tar.gz
        tar xf $PG_SOURCE_FILENAME.tar ; rm -f $PG_SOURCE_FILENAME.tar
        cd $PG_SOURCE_FILENAME
        rm -rf build
        mkdir build
        DIR=`pwd`
        ./configure --prefix=$DIR/build/$PG_HOME --with-openssl --with-pam --with-krb5 --enable-nls
        gmake
        gmake install
        cd build
        FILETOUPLOAD=postgresql$EXT
        tar -cvzf $FILETOUPLOAD opt/
        #tar xf $FILETOUPLOAD -C $WORKSPACE
        mvn deploy:deploy-file \
            -DgroupId=$PG_NAMESPACE \
            -DartifactId=$MVN_ARTIFACT_ID \
            -Dversion=$CLOUDERA_PG_VERSION \
            -Dfile=$FILETOUPLOAD \
            -Durl=$MVN_BASEURL \
            -DrepositoryId=cdh.snapshots.repo \
            -Dclassifier=$PG_CLASSIFIER
        mv -f $FILETOUPLOAD $TARGET_DIR/$PG_FILENAME
   else
         echo "Unexpected exit status $WGET_STATUS from wget, exiting"
         exit 1
   fi
fi
