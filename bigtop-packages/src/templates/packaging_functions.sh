# Looks up which subdirectory of /usr/lib or ${PARCELS_ROOT}/CDH/lib a JAR is owned by
# Outputs nothing if a symlink should not be made or the directory is unknown
# strip_versions <basename of JAR>
get_directory_for_jar() {
    case ${1} in
        avro*cassandra*) return;; # This is not included in our Avro distribution, but Mahout used to use it
        hadoop-client*) return;; # FIXME: We do not currently package this JAR. See CDH-19526.
        avro*) lib_dir='avro';;
        parquet*) lib_dir='parquet';;
        zookeeper*) lib_dir='zookeeper';;
        hadoop-yarn*) lib_dir='hadoop-yarn';;
        hadoop-hdfs*) lib_dir='hadoop-hdfs';;
        hadoop-mapreduce*) lib_dir='hadoop-mapreduce';;
        hadoop-core*) lib_dir='hadoop/client-0.20';;
        hadoop*) lib_dir='hadoop';;
        hbase-indexer*) lib_dir='hbase-solr/lib';;
        hbase-sep*) lib_dir='hbase-solr/lib';;
        hbase*) lib_dir='hbase';;
        hive-hcatalog*) lib_dir='hive-hcatalog/share/hcatalog';;
        hive-webhcat-java-client*) lib_dir='hive-hcatalog/share/webhcat/java-client';;
        hive*) lib_dir='hive/lib';;
        sentry*) lib_dir='sentry/lib';;
        solr*) lib_dir='solr';;
        lucene*) lib_dir='solr/webapps/solr/WEB-INF/lib';;
        kite*) lib_dir='kite';;
        *) return;;
    esac
    echo "/usr/lib/${lib_dir}"
}

# Strips all versioning info from a JAR file name (e.g. avro-1.7.5-cdh5.0.0-SNAPSHOT-hadoop2.jar -> avro-hadoop2.jar)
# strip_versions <file name>
function strip_versions() {
    # This regex matches upstream versions, plus CDH versions, betas and snapshots if they are present
    versions='s#-[0-9]\+.[0-9]\+.[0-9]\+\(-mr1\)\?\(-cdh[0-9\-\.]\+[0-9]\)\(-beta-[0-9]\+\)\?\(-SNAPSHOT\)\?\([-\.0-9]\+[0-9]\)\?##'
    echo ${1} | sed -e $versions
}

# Creates versionless symlinks to JARs in the same directory (e.g. /usr/lib/zookeeper/zookeeper.jar -> /usr/lib/zookeeper/zookeeper-3.4.5-cdh5.0.0-SNAPSHOT.jar)
# internal_versionless_symlinks <JAR files to link>
function internal_versionless_symlinks() {
    for file in ${@}; do
        (
            cd `dirname ${file}`
            base_jar=`basename ${file}`
            ln -s ${base_jar} `strip_versions ${base_jar}`
        )
    done
}

# Creates symlinks between one component and another, dependent component (e.g. /usr/lib/hadoop/avro.jar -> /usr/lib/avro/avro.jar)
# Assumes that internal versionless symlinks already exist in the dependency
# external_versionless_symlinks <prefix (or quoted list of prefixed) to exclude> <directories to scan for JARs>
function external_versionless_symlinks() {
    predicate=''
    skip=${1}; shift 1;
    # Find all files we might want to symlink (it's okay if this returns a superset of what we actually want to symlink)
    for prefix in avro parquet zookeeper hive hadoop hbase sentry solr lucene kite; do
        if [ -n "${predicate}" ]; then predicate="${predicate} -o "; fi
        predicate="${predicate} -name ${prefix}*.jar";
    done
    for dir in $@; do
        for old_jar in `find $dir -maxdepth 1 ${predicate}`; do
            base_jar=`basename $old_jar`;
            for prefix in ${skip}; do
                if [[ "${base_jar}" =~ ^${prefix} ]]; then continue 2; fi
            done
            new_jar=`strip_versions $base_jar`
            new_dir=`get_directory_for_jar ${base_jar}`
            if [ -z "${new_dir}" ]; then continue; fi
            rm $old_jar && ln -fs ${new_dir}/${new_jar} $dir/
        done
    done
}
