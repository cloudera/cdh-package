#!/bin/bash

set -e

exception_list=(
'netty.Final.jar=netty-*Final*.jar'
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
    echo ${1%.*}-*.jar
  fi
}

rm -f out*.txt 

# Adding the latest repo file to be able to run rpm queries if need be.
# Currently this is not needed.
repo_file_location=http://repos.jenkins.cloudera.com/cdh5-static/redhat/6/x86_64/cdh/cloudera-cdh5.repo
wget -O /etc/yum.repos.d/cloudera-cdh5.repo ${repo_file_location}
yum clean all > /dev/null
yum-config-manager --enable cloudera-cdh5 > /dev/null

# Download the parcel
parcel_dir=parcel_dir
wget -r -nH --no-parent -A '*el6.parcel' --cut-dirs=4 http://repos.jenkins.cloudera.com/cdh5-static/parcels/latest/

# Only testing, remove parcel_dir once completed.
mkdir -p ${parcel_dir}
tar zxf *el6.parcel -C ${parcel_dir} --strip 1

jar_file=''
for jar_file in `find ${parcel_dir} -name "*.jar" -type f`; do
 basename ${jar_file} >> out2.txt
done

# Remove jars that have identical version number.
# This should not exist, if it does exist duplicate detection needs to be updated 
# for third party jars.
cat out2.txt | sort | uniq  > out3.txt
cp out3.txt out3_copy.txt
number_of_jars_with_version=`wc out2.txt -l | cut -d ' ' -f1`
number_of_unique_jars_with_version=`wc out3.txt -l | cut -d ' ' -f1`

echo $number_of_jars_with_version
echo $number_of_unique_jars_with_version

strip_versions out3.txt

# Now get the number of jars that differ by version number. 
# Finally sort this in descending order (number of different versions found for the same jar)
cat out3.txt | sort | uniq -dc | sort -r > out4.txt

sed -i 's/^\s*//g' out4.txt

jar_file=''
for jar_file_1 in `head -5 out4.txt`; do
 if [[ ${jar_file_1} =~ ^[0-9]+$ ]]; then
   number_of_hits=${jar_file_1}
   continue
 fi
 jar_file=`get_search_pattern ${jar_file_1}`
 
 # Find all matches to all versions of the jar.
 echo "---------------------------------" >> out6.txt
 echo "Jar file: ${jar_file}. Number of unique versions: ${number_of_hits}" >> out6.txt
 modified_jar_file=`echo ${jar_file} | sed -e 's/*/\.*/g'`
 grep -i ^${modified_jar_file%.*}.*.jar out3_copy.txt >> out6.txt
 echo "---------------------------------" >> out6.txt
 for file in `find ${parcel_dir} -name ${jar_file%.*}*.jar -type l`; do
   symlink_target=`readlink ${file}`
   echo "${file} --> ${symlink_target}" >> out6.txt
 done
done
