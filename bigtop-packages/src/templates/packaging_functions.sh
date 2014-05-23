# Looks up which subdirectory of /usr/lib or ${PARCELS_ROOT}/CDH/lib a JAR is owned by
# strip_versions <basename of JAR>
get_directory_for_jar() {
    case ${1} in
        avro*) lib_dir='avro';;
        parquet*) lib_dir='parquet';;
        zookeeper*) lib_dir='zookeeper';;
        hadoop-yarn*) lib_dir='hadoop-yarn';;
        hadoop-hdfs*) lib_dir='hadoop-hdfs';;
        hadoop-mapreduce*) lib_dir='hadoop-mapreduce';;
        hadoop*) lib_dir='hadoop';; # FIXME: hadoop-client isn't in any Hadoop package!
        hive-hcatalog*) lib_dir='hive-hcatalog/share/hcatalog';;
        hive-webhcat-java-client*) lib_dir='hive-hcatalog/share/webhcat/java-client';;
        hive*) lib_dir='hive/lib';;
    esac
    echo "/usr/lib/${lib_dir}"
}

function strip_versions() {
    # This regex matches upstream versions, plus CDH versions, betas and snapshots if they are present
    versions='s#-[0-9]\+.[0-9]\+.[0-9]\+\(-cdh[0-9\-\.]\+\)\(-beta-[0-9]\+\)\?\(-SNAPSHOT\)\?\([-\.0-9]\+[0-9]\)\?##'
    timestamps='s#-[0-9]\{8\}\.[0-9]\{6\}-[0-9]\+##'
    echo ${1} | sed -e $versions | sed -e $timestamps
}

function internal_versionless_symlinks() {
    for file in ${@}; do
        (
            cd `dirname ${file}`
            base_jar=`basename ${file}`
            ln -s ${base_jar} `strip_versions ${base_jar}`
        )
    done
}

function external_versionless_symlinks() {
    predicate=''
    skip=${1}; shift 1;
    for prefix in avro parquet zookeeper hive hadoop; do
        if [ "${prefix}" == "${skip}" ]; then
            continue;
        fi
        if [ -z "${predicate}" ]; then
            predicate="-name ${prefix}*.jar";
        else
            predicate="${predicate} -o -name ${prefix}*.jar";
        fi
    done
    for dir in $@; do
        for old_jar in `find $dir -maxdepth 1 $predicate | grep -v 'cassandra' | grep -v 'hadoop-client'`; do
            base_jar=`basename $old_jar`; new_jar=`strip_versions $base_jar`
            rm $old_jar && ln -fs `get_directory_for_jar ${base_jar}`/$new_jar $dir/
        done
    done
}
