#!/bin/bash
set -e

MYDIR=`dirname "${BASH_SOURCE[0]}"`

. ${MYDIR}/../../templates/packaging_functions.sh

function checkName() {
    if [[ $1  = avro* ]] ; then
      return 0
    fi
    if [[ $1  = crunch* ]] ; then
      return 0
    fi
    if [[ $1  = zookeeper* ]] ; then
      return 0
    fi
    if [[ $1  = hive* ]] ; then
      return 0
    fi
    if [[ $1  = hadoop* ]] ; then
      return 0
    fi
    if [[ $1  = hbase* ]] ; then
      return 0
    fi
    if [[ $1  = search* ]] ; then
      return 0
    fi
    if [[ $1  = sentry* ]] ; then
      return 0
    fi
    if [[ $1  = solr* ]] ; then
      return 0
    fi
    if [[ $1  = lucene* ]] ; then
      return 0
    fi
    if [[ $1  = kite* ]] ; then
      return 0
    fi
    if [[ $1  = spark* ]] ; then
      return 0
    fi
    if [[ $1  = sqoop* ]] ; then
      return 0
    fi
    if [[ $1  = trevni* ]] ; then
      return 0
    fi
    if [[ $1  = pig* ]] ; then
      return 0
    fi
    if [[ $1  = parquet* ]] ; then
      return 0
    fi
    return 1
}

EXIT_STATUS=0
while read line
do
	IFS="|"
    set $line
    #target is the unmodified link name
    target=`basename $2`

    #expected_linkname is the name we actually see on the filesystem
    expected_linkname=`basename $1`
    if ! checkName $target
    then 
        echo "skipping $target"
        continue
    fi
    
    if [[ ${2} =~ ^lib ]] ; then 
        echo "skipping $target"
        continue
    fi
        

    #actual_linkname is the versionless name calculated by function under test
	actual_linkname=`strip_versions $target`

    if [ $target != $expected_linkname ] ; then
        modified="modifiedName"
    else
        modified="retainedName"
    fi    

    if [ $actual_linkname != $expected_linkname ] ; then
        testStatus=Fail
        echo "OriginalLine:$line"
        EXIT_STATUS=1
    else
        testStatus=Pass
    fi
    echo "$testStatus|$modified|Target:$target|ExpectedName:$expected_linkname|Actual:$actual_linkname"

done
exit $EXIT_STATUS
