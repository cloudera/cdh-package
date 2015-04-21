#!/bin/bash

set -ex

exception_list=(
'netty.Final.jar=netty-*Final*.jar'
'bonecp.RELEASE.jar=bonecp-*RELEASE*.jar'
'javassist-GA.jar=javassist-*GA*.jar'
'postgresql.jdbc4.jar=postgresql-*jdbc4*.jar'
'servlet-api.jar=servlet-api*.jar'
)

# String versions from jars
function strip_versions() {
    sed -i 's/-SNAPSHOT//g' $1
    sed -i 's/-beta-[0-9]\+//g' $1
    sed -i 's/-\(cdh\|hbase\|hadoop\)[0-9]\.[0-9.]\+\?[0-9]//g' $1
    sed -i 's/\(-\|_\)[0-9]\+\.[-0-9\.]\+\?[0-9]//g' $1
    sed -i 's/\([^.]\)jar$/\1.jar/' $1
}

function get_search_pattern() {
  for exceptions in ${exception_list[@]}; do
    local search_string=`echo ${exceptions} | cut -d'=' -f1`
    if [ ${1} = ${search_string}  ]; then
      result_string=`echo ${exceptions} | cut -d'=' -f2`
      break
    fi
  done
  if [ ! -z ${result_string} ]; then
    echo ${result_string}
  else
    echo ${1%.*}-[0-9].*.jar
  fi
}

# foo-1.jar
# foo-2.jar
# bar-1.jar
all_unique_jars_with_versions=all_unique_jars_with_versions.txt

# foo.jar
# bar.jar
all_unique_jars_without_versions=all_unique_jars_without_versions.txt

# 5 foo.jar
# 3 bar.jar
all_unique_jars_without_versions_count=all_unique_jars_without_versions_count.txt

# Formatted output which will be parsed and pushed to the database.
xml_formatted_output=xml_formatted_output.xml

rm -f ${all_unique_jars_with_versions} ${all_unique_jars_without_versions}
rm -f ${all_unique_jars_without_versions_count} ${xml_formatted_output}

# Source toolchain.
. /mnt/toolchain/toolchain.sh

is_java_in_path=`java -version 2>/dev/null ||:`
is_groovy_in_path=`groovy -version 2>/dev/null ||:`

if [ -z "${is_java_in_path}" ]; then
    sudo yum install -y openjdk-64*
    JAVA_HOME="/opt/toolchain/`basename /opt/toolchain/openjdk*`/"
    PATH=$JAVA_HOME/bin:$PATH
fi

if [ -z "${is_groovy_in_path}" ]; then
    sudo yum install -y groovy*
    GROOVY_HOME=/opt/toolchain/`basename /opt/toolchain/groovy*`/
    PATH=$GROOVY_HOME/bin:$PATH
fi

export PATH="${PATH}"

# Download the parcel
parcel_dir="parcel-dir"
wget -r -nH --no-parent -A '*el6.parcel' --cut-dirs=4 http://repos.jenkins.cloudera.com/cdh5-static/parcels/5.5/

# Only testing, remove parcel_dir once completed.
mkdir -p ${parcel_dir}
tar zxf *el6.parcel -C ${parcel_dir} --strip 1

# Remove jars that have identical version number.
# This should not exist, if it does exist duplicate detection needs to be updated 
# for third party jars.
find ${parcel_dir} -name "*.jar" -type f | sed -e 's/^.*\///' | sort | uniq > ${all_unique_jars_with_versions}

cp ${all_unique_jars_with_versions} ${all_unique_jars_without_versions} #out3.txt out3_copy.txt

strip_versions ${all_unique_jars_without_versions}

# Now get the number of jars that differ by version number. 
# Finally sort this in descending order (number of different versions found for the same jar)
cat ${all_unique_jars_without_versions} | sort | uniq -dc | sort -r > ${all_unique_jars_without_versions_count}

# Remove all leading spaces from each line.
sed -i 's/^\s*//g' ${all_unique_jars_without_versions_count}

rm -rf ${xml_formatted_output}

jar_file=''
echo "<thirdpartyHarmonization>" >> ${xml_formatted_output}
echo "<date>`date +%Y-%m-%d\ %H:%M:%S`</date>" >> ${xml_formatted_output}
for jar_file_1 in `cat ${all_unique_jars_without_versions_count}`; do
 if [[ ${jar_file_1} =~ ^[0-9]+$ ]]; then
   number_of_hits=${jar_file_1}
   continue
 fi
 jar_file=`get_search_pattern ${jar_file_1}`
 
 # Find all matches to all versions of the jar.
 echo "<jarFile>" >> ${xml_formatted_output}
 echo "<jarFileName>${jar_file_1}</jarFileName>" >> ${xml_formatted_output}
 echo "<jarFileSearchPattern>${jar_file}</jarFileSearchPattern>" >> ${xml_formatted_output}
 echo "<jarFileCount>${number_of_hits}</jarFileCount>" >> ${xml_formatted_output}
 echo "<jarFileWithVersions>" >> ${xml_formatted_output}
 modified_jar_file=`echo ${jar_file} | sed -e 's/*/\.*/g'`
 grep -i ^${modified_jar_file%.*}.*.jar ${all_unique_jars_with_versions} >> ${xml_formatted_output}
 echo "</jarFileWithVersions>" >> ${xml_formatted_output}
 echo "<jarFileSymlinks>" >> ${xml_formatted_output}
 rm -f temp.txt
 
 for file in `find ${parcel_dir}/lib -regex "^.*/${modified_jar_file%.*}.*.jar" -type l`; do
   symlink_target=`readlink ${file}`
   component=`echo ${file} | cut -d'/' -f3`
   jar_with_version=`basename "${file}"`
   echo "${component}->${jar_with_version}" >> temp.txt
 done
 cat temp.txt | sort | uniq >> ${xml_formatted_output}
 echo "</jarFileSymlinks>" >> ${xml_formatted_output}
 echo "</jarFile>" >> ${xml_formatted_output}
done
echo "</thirdpartyHarmonization>" >> ${xml_formatted_output}

# Need to have mysql-connector in the java classpath.
sudo wget http://www.sf.cloudera.com/~mnarayan/Toolchain/mysql-connector-java-5.1.35-bin.jar

# Parse this xml file, and generate data that will be bulk loaded into a mysql db
groovy -cp ./mysql-connector-java-5.1.35-bin.jar ./ParseTextFile.groovy
