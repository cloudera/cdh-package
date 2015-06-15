#!/bin/bash

set -ex

exception_list=(
'netty.Final.jar=netty-*Final*.jar'
'bonecp.RELEASE.jar=bonecp-*RELEASE*.jar'
'javassist-GA.jar=javassist-*GA*.jar'
'postgresql.jdbc4.jar=postgresql-*jdbc4*.jar'
'servlet-api.jar=servlet-api*.jar'
'xpp3_minc.jar=xpp3_min*.jar'
'java-cupa.jar=java-cup*.jar'
'ant-contribb3.jar=ant-contrib-*.jar'
'jetty.cloudera.2.jar=jetty-([0-9]{1,}\.)+[0-9]{1,}.cloudera.2.jar'
'jetty.cloudera.4.jar=jetty-([0-9]{1,}\.)+[0-9]{1,}.cloudera.4.jar'
'jetty-all.jar=jetty-all-([0-9]{1,}\.)+[0-9]{1,}.*.jar'
'poi-beta2.jar=poi-([0-9]{1,}\.)+[0-9]{1,}-beta2.jar'
'post.jar=post.jar'
'catalina.jar=catalina.jar'
)

# String versions from jars
function strip_versions() {
    sed -i 's/-SNAPSHOT//g' $1
    sed -i 's/-beta-[0-9]\+//g' $1
    sed -i 's/-\(cdh\|hbase\|hadoop\)[0-9]\.[0-9.]\+\?[0-9]//g' $1
    sed -i 's/\(-\|_\)[0-9]\+\.[-0-9\.]\+\?[0-9]//g' $1
    sed -i 's/\([^.]\)jar$/\1.jar/' $1
    # Some jars have versions with a date stamp. Strip these out.
    sed -i 's/\.v[0-9]*//' $1
}

function get_search_pattern() {
  local result_string=""
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
    echo "${1%.*}-([0-9]{1,}\.)+[0-9]{1,}.jar"
  fi
}

# This function downloads the parcel from the url passed and collects information about
# all thirdparty jars that are bundled. Note that all thirdparty jars that occur only once
# are ommited.
# Data is collected in two separate files. One of them provides information occurances of a
# particular jar and the other provides information about which a mapping of a component to the
# jar it bundles. Data in these two files are pushed into a mysql table.
#
# Relavant information:
# At the end of each run, data is collected and pushed into mysql tables.
# Mysql server: mthtest3.ent.cloudera.com  // This needs to be moved to a better location.
# Database: thirdparty_harmonization
# Tables:
#   thirdparty_jars_stats
#   thirdparty_jars_component_map
function analyze_parcel()
{
  local passed_url=${1}

  echo "Analyzing el6 parcel from URL ${passed_url}"

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

  # Ensure there are no parcels to begin with.
  rm -rf *el6.parcel

  # Download the parcel
  parcel_dir="parcel-dir"
  wget -r -nH --no-parent -A '*el6.parcel' --cut-dirs=4 ${passed_url}

  # Remove parcel_dir once completed.
  rm -rf ${parcel_dir}
  mkdir -p ${parcel_dir}
  tar zxf *el6.parcel -C ${parcel_dir} --strip 1

   # Sourcing common functions.
   . ./common.sh

  parcel_name=`basename *el6.parcel`
  cdh_version=`echo $parcel_name| cut -d'-' -f1-2`
  cdh_jar_versions=`get_cdh_jar_versions ${parcel_dir}`
  count_unique_cdh_jar_versions=`echo ${cdh_jar_versions} | wc -w`
  echo "[CHECK_CDH_JAR_VERSIONS]: ${cdh_jar_versions}"
  if [ ${count_unique_cdh_jar_versions} -gt 1 ]; then
      echo "[CHECK_CDH_JAR_VERSIONS_ERROR]: ${count_unique_cdh_jar_versions} unique versions of cdh version found across first-party jars" >&2
      exit 1
  fi

  # Remove jars that have identical version number.
  # This should not exist, if it does exist duplicate detection needs to be updated
  # for third party jars.
  find ${parcel_dir} -name "*.jar" -type f | grep -v "cdh[0-9]" | sed -e 's/^.*\///' | sort | uniq > ${all_unique_jars_with_versions}

  cp ${all_unique_jars_with_versions} ${all_unique_jars_without_versions} #out3.txt out3_copy.txt

  strip_versions ${all_unique_jars_without_versions}

  # Now get the number of jars that differ by version number.
  # Finally sort this in descending order (number of different versions found for the same jar)
  cat ${all_unique_jars_without_versions} | sort | uniq -c | sort -r > ${all_unique_jars_without_versions_count}

  # Remove all leading spaces from each line.
  sed -i 's/^\s*//g' ${all_unique_jars_without_versions_count}

  rm -rf ${xml_formatted_output}

  jar_file=''
  echo "<thirdpartyHarmonization>" >> ${xml_formatted_output}
  echo "<date>`date +%Y-%m-%d\ %H:%M:%S`</date>" >> ${xml_formatted_output}
  echo "<parcel>$parcel_name</parcel>" >> ${xml_formatted_output}
  echo "<cdh_version>$cdh_version</cdh_version>" >> ${xml_formatted_output}
  for jar_file_1 in `cat ${all_unique_jars_without_versions_count}`; do
    if [[ ${jar_file_1} =~ ^[0-9]+$ ]]; then
      number_of_hits=${jar_file_1}
      continue
    fi
    jar_file=`get_search_pattern ${jar_file_1}`

    # Find all matches to all versions of the jar.
    echo "<jarFile>" >> ${xml_formatted_output}
    echo "<jarFileName>${jar_file_1}</jarFileName>" >> ${xml_formatted_output}
    echo "<jarFileCount>${number_of_hits}</jarFileCount>" >> ${xml_formatted_output}
    echo "<jarFileWithVersions>" >> ${xml_formatted_output}
    modified_jar_file=`echo ${jar_file} | sed -e 's/*/\.*/g'`

    # Widen the search pattern progressively
    if ! egrep "^${modified_jar_file}" ${all_unique_jars_with_versions} >> ${xml_formatted_output} ; then
      # Replace the last occurance of .jar with .*.jar
      modified_jar_file=`echo ${jar_file_1%.*}.*.jar`
      if ! egrep "^${modified_jar_file}" ${all_unique_jars_with_versions} >> ${xml_formatted_output} ; then
        # Replace the last occurance of - with .*
        modified_jar_file=`echo ${jar_file_1} | sed 's/\(.*\)-/\1\.*/'`
        if ! egrep "^${modified_jar_file}" ${all_unique_jars_with_versions} >> ${xml_formatted_output} ; then
          # Most aggressive search pattern. Replace all occurance of . or - or _ with .*
          modified_jar_file=`echo ${jar_file_1} | sed 's/\(\.\|-\|_\)/\.\*/g'`
          egrep "^${modified_jar_file}" ${all_unique_jars_with_versions} >> ${xml_formatted_output}
        fi
      fi
    fi

    echo "</jarFileWithVersions>" >> ${xml_formatted_output}
    echo "<jarFileSearchPattern>${modified_jar_file}</jarFileSearchPattern>" >> ${xml_formatted_output}
    echo "<jarFileSymlinks>" >> ${xml_formatted_output}
    rm -f temp.txt

    for file in `find ${parcel_dir}/lib -regextype posix-extended -regex "^.*/${modified_jar_file}" -type l`; do
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

  # Run analysis for a particular version of CDH.
  groovy -cp ./mysql-connector-java-5.1.35-bin.jar ./AnalyzeDb.groovy $analysis_file $cdh_version
  cat analysis.txt
}

if [ $# -lt 1 ]; then
  echo "Need to pass the CDH version number for which analysis needs to be done." >&2
  echo "ex: thirdparty_jar_harmonization.sh cdh5.3.x cdh5" >&2
  exit 1
fi

# First pass to check if the URL is correct.
for version_strings in $@; do
  constructed_url="http://repos.jenkins.cloudera.com/${version_strings}-nightly/parcels/5/"
  if ! curl --output /dev/null --silent --head --fail ${constructed_url}; then
    echo "URL ${constructed_url} does not exist. Terminating." >&2
    exit 1
  fi
done

# Second pass to actually download the parcel and perform analysis.
version_strings=""
analysis_file="analysis.txt"

# Remove the file that will be created when Analysis is done after pushing data into mysql tables.
rm -f analysis.txt
for version_strings in $@; do
  constructed_url="http://repos.jenkins.cloudera.com/${version_strings}-nightly/parcels/5/"
  analyze_parcel ${constructed_url}
done

# If the analysis file is empty remove it before returning.
if [ -s $analysis_file ]; then
  rm -f $analysis_file
fi

