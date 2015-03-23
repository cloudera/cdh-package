#!/bin/bash

set -ex

# Go over all the dependencies and clean them up.
function clean_dependencies() {
  if [ $# != 1 ]; then
    echo "Usage: clean_dependencies file_containing_dependencies" >&2
    exit 1
  fi

  # Doing some cleanup.
  sed -i '\,^\(/\|rpmlib\|config\|lib\|bigtop\),d' ${1}
  sed -i 's/\s*$//g' ${1}
}

# Get all dependencies for a given component.
# Example: get_all_dependencies kite out.txt
#
#  avro-libs
#  hadoop
#  hadoop-0.20-mapreduce
#  hadoop-client
#  hadoop-hdfs
#  hadoop-mapreduce
#  hadoop-yarn
#  kite
#  parquet
#  parquet-format
#  sentry
#  solr
#  zookeeper
#
function get_all_dependencies() {
  if [ $# != 3 ]; then
    echo "Usage: get_all_dependencies component_name out_file match_string" >&2
    exit 1
  fi

  temp_file=temp.txt
  rm -f ${temp_file} ${2}

  # Get all dependencies that will be downloaded for a particular package installation.
  match=${3}
  repotrack -u $1 -r cloudera-cdh5 | grep -i ${match} > ${temp_file}

  # Convert a link like :http://repos.jenkins.cloudera.com/cdh5-static/redhat/6/x86_64/cdh/5/RPMS/noarch/avro-libs-1.7.6+cdh5.5.0+87-1.cdh5.5.0.p0.531.el6.noarch.rpm to avro-libs
  for line in `cat ${temp_file}`; do
    basename ${line} | cut -d'+' -f1 | sed -e 's/-[0-9]\+\.[0-9\.]\+\?[0-9]\+$//g' >> ${2}
  done

  rm -f ${temp_file}
  clean_dependencies ${2}
}

# Get list of all files in the package.
# For each package in the list, run rpm -ql to get all the files that will get installed as part of 
# installing the package. The caveat is that this will not contain files that get created as part
# of the post-install script.
function get_all_files_in_package() {
  out_file=''
  out_file=${1}; shift 1;
  rm -f ${out_file}

  for package in $@; do
    echo "package: ${package}"
    rpm -ql ${package} >> ${out_file}
  done
}

# Ignore some of the broken symlinks. They are expected to be broken.
#
function remove_exceptions() {
  if [ $# != 1 ]; then
    echo "Usage: remove_exceptions symlink_file" >&2
    exit 1
  fi

  sed -i '\,/usr/include/python2.6,d' $1
  sed -i '\,/usr/lib64/python2.6,d' $1

  # FixMe: This symlink is planned to be dropped in the packaging code
  # after necessary changes are made to include this path to the classpath of the component.
  # Remove exception after CDH-26342 is fixed.
  sed -i '\,/var/lib/oozie/ext-2.2,d' $1
}


  external_symlinks_in_component=symlinks_in_component.txt
  files_in_dependent_packages=all_files_from_dependencies.txt
  dependencies_file=dependencies_file.txt
  symlink_map_file=symlink_map_file.txt
  final_output_file=final_output.txt
  packages_file=packages.txt
  rm -f ${external_symlinks_in_component} ${files_in_dependent_packages} ${final_output_file} ${dependencies_file} ${symlink_map_file} ${packages_file}

  # Remove repo file.
  rm -f /etc/yum.repos.d/cloudera-cdh5.repo

  # Install and enable repo.
  repo_file_location=http://repos.jenkins.cloudera.com/cdh5-static/redhat/6/x86_64/cdh/cloudera-cdh5.repo
  match_string=`echo ${repo_file_location%/*/*}`
  wget -O /etc/yum.repos.d/cloudera-cdh5.repo ${repo_file_location}
  yum clean all
  yum-config-manager --enable cloudera-cdh5

  # Get the list of packages from the repo.
  # Clean up the file generated to remove blank lines
  yum --disablerepo="*" --enablerepo="cloudera-cdh5" list available |  sed -e '1,/Available Packages/d' | cut -d' ' -f1 > ${packages_file}
  sed -i '/^$/d' ${packages_file}

  # Error: hadoop-0.20-mapreduce-jobtrackerha conflicts with hadoop-0.20-mapreduce-jobtracker
  # Error: hadoop-0.20-conf-pseudo conflicts with hadoop-conf-pseudo
  # 0.20-conf-pseudo has a dependency on 0.20-mapreduce-jobtracker
  # Resolving by not installing hadoop-0.20-mapreduce-jobtracker and hadoop-0.20-conf-pseudo.
  sed -i '/\(hadoop-0.20-mapreduce-jobtracker\.x86_64$\|hadoop-0.20-conf-pseudo\)/d' ${packages_file}

  #PACKAGES="avro-tools crunch flume-ng hadoop hadoop-hdfs-fuse hadoop-hdfs-nfs3 hadoop-httpfs hbase-solr hive hive-hbase hive-webhcat hue-beeswax hue-hbase hue-impala hue-pig hue-plugins hue-rdbms hue-search hue-spark hue-sqoop hue-zookeeper impala impala-shell kite llama mahout oozie pig pig-udf-datafu search sentry solr-mapreduce spark-core spark-python sqoop sqoop2 whirr"

  # Install yum-utils which provides repotrack
  yum -y install yum-utils

  # Clean install all packages.
  yum -y remove bigtop-utils
  yum -y install `cat ${packages_file}`

  # Temp files
  temp_file_1=temp_file_1.txt
  temp_file_2=temp_file_2.txt
  # Go over each component in the list and do the following
  #
  # 1. Get all files packaged for the component.
  # 2. Get all dependencies and then list all the files in each of the dependencies.
  # 3. Figure out all files in the component that are symlinks to external files.
  # 4. Diff (3) and (2) to get broken symlinks
  #
  # Note: Internal symlinks are already validated as part of building the package, so they are ignored here.
  #
  for component in `cat ${packages_file}`; do

    rm -f ${temp_file_1} ${temp_file_2} ${symlink_map_file} ${external_symlinks_in_component}
    echo "----------------"
    echo "List of dependencies for ${component}"
    get_all_dependencies ${component} ${dependencies_file} ${match_string}
    echo "----------------"

    for file in `rpm -ql ${component}`; do
      if [ -h ${file} ]; then
       link_location=$(readlink ${file})
       if [[ ${link_location} =~ ^(/) ]]; then
         echo "${link_location}" >> ${external_symlinks_in_component}
         echo "${file} -> ${link_location}" >> ${symlink_map_file}
       fi
      fi
    done

    if [ -e ${symlink_map_file} ]; then
      get_all_files_in_package ${files_in_dependent_packages} `cat ${dependencies_file}`
      sed -i 's,//\+,/,g' ${external_symlinks_in_component}
      sed -i 's,/$,,' ${external_symlinks_in_component}

      # Diff external symlinks in component with files in all its dependencies
      # If the diff is not empty, then we have broken symlinks and probably we need 
      # to update the dependencies in that package.
      fgrep -x -f ${files_in_dependent_packages} -v ${external_symlinks_in_component} | tee ${temp_file_1}
      if [ -s ${temp_file_1} ]; then
        sort ${temp_file_1} | uniq | tee ${temp_file_2}

        # Symlinks to conf is created in the postinstall step of installing the package
        # and they don't exist in the package itself. So, ignore.
	sed -i '/\(conf\|config\|conf\.dist\)\/\?/d' ${temp_file_2}

	# Some symlinks are expected to be broken.
	remove_exceptions ${temp_file_2}

	if [ -s ${temp_file_2} ]; then
          echo "Broken links in ${component} :" >> ${final_output_file}
          for broken_links in `cat ${temp_file_2}`; do
            grep -i ${broken_links} ${symlink_map_file} >> ${final_output_file}
          done
	fi
      fi
    fi
  done

  # Cleanup
  rm -f ${external_symlinks_in_component} ${files_in_dependent_packages} ${dependencies_file} ${symlink_map_file}
  rm -f ${temp_file_1} ${temp_file_2}
  if [ -e ${final_output_file} ]; then
    echo "There are broken symlinks in one or more packages. Failing run." >&2
    cat  ${final_output_file} >&2
    exit 1
  fi
