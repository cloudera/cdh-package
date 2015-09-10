#! /usr/bin/env bash

# This is a list of possible paths for the JDK in the order in which we should prefer them
JDKs='/usr/java/jdk1.7.0_67-cloudera
    /usr/java/jdk1.7.0_67
    /usr/java/jdk1.7.0_66
    /usr/lib/jvm/jre-openjdk
    /usr/lib/jvm/java-1.7.0-openjdk-1.7.0.75.x86_64
    /usr/lib/jvm/java-1.8.0-openjdk-1.8.0.31-1.b13.el6_6.x86_64
    /usr/java/jdk1.6.0_31
    /usr/lib/jvm/java-1.6.0-openjdk-1.6.0.34.x86_64
    /usr/lib/jvm/jre-1.6.0-openjdk.x86_64'

# For each path, create it and install a 'java' executable that would pass bigtop-detect-javahome's test
for JDK in ${JDKs}; do
    mkdir -p ${JDK}/bin
    touch ${JDK}/bin/java
done

# For each JDK, ensure it is the one found first, then delete so we can verify that the next takes precedence
for JDK in ${JDKs}; do
    unset JAVA_HOME
    source /bin/bigtop-detect-javahome
    if [ "${JAVA_HOME}" != ${JDK} ]; then
        echo "${JAVA_HOME} found, expected ${JDK} next"
        exit 1
    fi
    rm -r ${JDK}
done

exit 0

