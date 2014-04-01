# Replace every Avro or Parquet jar with a symlink to the versionless symlinks in our distribution
# This regex matches upstream versions, plus CDH versions, betas and snapshots if they are present

function versionless_symlinks() {
    versions='s#-[0-9].[0-9].[0-9]\(-cdh[0-9\-\.]*\)\?\(-beta-[0-9]\+\)\?\(-SNAPSHOT\)\?##'
    timestamps='s#-[0-9]\{8\}\.[0-9]\{6\}-[0-9]\+##'
    for dir in $@; do
        for old_jar in `find $dir -maxdepth 1 -name avro*.jar -o -name parquet*.jar | grep -v 'cassandra'`; do
            base_jar=`basename $old_jar`; new_jar=`echo $base_jar | sed -e $versions | sed -e $timestamps`
            rm $old_jar && ln -fs /usr/lib/${base_jar/[-.]*/}/$new_jar $dir/
        done
    done
}
