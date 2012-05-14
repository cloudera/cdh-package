#
# Hadoop RPM spec file
#
%define hadoop_name hadoop-0.20
%define etc_hadoop /etc/hadoop
%define config_hadoop %{etc_hadoop}/conf
%define lib_hadoop_dirname /usr/lib
%define lib_hadoop %{lib_hadoop_dirname}/%{name}
%define lib_client %{lib_hadoop_dirname}/hadoop/client-0.20
%define log_hadoop_dirname /var/log
%define log_hadoop %{log_hadoop_dirname}/%{name}
%define bin_hadoop %{_bindir}
%define man_hadoop %{_mandir}
%define src_hadoop /usr/src/%{name}
%define hadoop_username mapred
%define hadoop_services jobtracker tasktracker
# Hadoop outputs built binaries into %{hadoop_build}
%define hadoop_src_path $RPM_BUILD_DIR/hadoop-@HADOOP_VERSION@
%define static_images_dir src/webapps/static/images
%define cloudera_version %{mr1_patched_version}
%define release_version %{mr1_release}
%define package_version %{mr1_version}
%define apache_branch 0.20
%define hadoop_build_path build/hadoop-%{cloudera_version}
%define jar_deps_hadoop hadoop-annotations,hadoop-auth,hadoop-common,hadoop-hdfs

%ifarch i386
%global hadoop_arch Linux-i386-32
%endif
%ifarch amd64 x86_64
%global hadoop_arch Linux-amd64-64
%endif
%ifarch noarch
%global hadoop_arch ""
%endif

%if  %{!?suse_version:1}0
# brp-repack-jars uses unzip to expand jar files
# Unfortunately aspectjtools-1.6.5.jar pulled by ivy contains some files and directories without any read permission
# and make whole process to fail.
# So for now brp-repack-jars is being deactivated until this is fixed.
# See CDH-2151
%define __os_install_post \
    /usr/lib/rpm/redhat/brp-compress ; \
    /usr/lib/rpm/redhat/brp-strip-static-archive %{__strip} ; \
    /usr/lib/rpm/redhat/brp-strip-comment-note %{__strip} %{__objdump} ; \
    /usr/lib/rpm/brp-python-bytecompile ; \
    %{nil}

%define doc_hadoop %{_docdir}/%{name}-%{package_version}
%define alternatives_cmd alternatives

%global initd_dir %{_sysconfdir}/rc.d/init.d

%else

# Deactivating symlinks checks
%define __os_install_post \
    %{suse_check} ; \
    /usr/lib/rpm/brp-compress ; \
    %{nil}

%define doc_hadoop %{_docdir}/%{name}
%define alternatives_cmd update-alternatives

%global initd_dir %{_sysconfdir}/rc.d

%endif


# Even though we split the RPM into arch and noarch, it still will build and install
# the entirety of hadoop. Defining this tells RPM not to fail the build
# when it notices that we didn't package most of the installed files.
%define _unpackaged_files_terminate_build 0

# RPM searches perl files for dependancies and this breaks for non packaged perl lib
# like thrift so disable this
%define _use_internal_dependency_generator 0

Name: %{hadoop_name}-mapreduce
Version: %{package_version}
Release: %{release_version}
Summary: Hadoop is a software platform for processing vast amounts of data
License: Apache License v2.0
URL: http://hadoop.apache.org/core/
Group: Development/Libraries
Source0: mr1-%{cloudera_version}.tar.gz
Source1: hadoop-0.20.default
Source2: hadoop-init.tmpl
Source3: hadoop-init.tmpl.suse
Source4: hadoop.nofiles.conf
Source5: do-component-build
Source6: install_hadoop.sh
Source7: README
Source8: hadoop-metrics.properties
Source9: core-site.xml
Source10: hdfs-site.xml
Source11: mapred-site.xml
Source12: log4j.properties
Source13: mapred.conf
Buildroot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id} -n -u)
BuildRequires: lzo-devel, python >= 2.4, git, automake, autoconf
Requires: hadoop, hadoop-hdfs, sh-utils, textutils, /usr/sbin/useradd, /usr/sbin/usermod, /sbin/chkconfig, /sbin/service

BuildArch: i386 amd64 x86_64

%if  %{?suse_version:1}0
BuildRequires: libopenssl-devel, gcc-c++, ant, ant-nodeps, ant-trax
# Required for init scripts
Requires: insserv
%else
BuildRequires: libtool, redhat-rpm-config
# Required for init scripts
Requires: redhat-lsb
%endif

%description
Hadoop is a software platform that lets one easily write and
run applications that process vast amounts of data.

Here's what makes Hadoop especially useful:
* Scalable: Hadoop can reliably store and process petabytes.
* Economical: It distributes the data and processing across clusters
              of commonly available computers. These clusters can number
              into the thousands of nodes.
* Efficient: By distributing the data, Hadoop can process it in parallel
             on the nodes where the data is located. This makes it
             extremely rapid.
* Reliable: Hadoop automatically maintains multiple copies of data and
            automatically redeploys computing tasks based on failures.

Hadoop implements MapReduce, using the Hadoop Distributed File System (HDFS).
MapReduce divides applications into many small blocks of work. HDFS creates
multiple replicas of data blocks for reliability, placing them on compute
nodes around the cluster. MapReduce can then process the data where it is
located.

%package jobtracker
Summary: Hadoop Job Tracker
Group: System/Daemons
Requires: %{name} = %{version}-%{release}
Conflicts: hadoop-0.20-jobtracker
BuildArch: noarch

%description jobtracker
The jobtracker is a central service which is responsible for managing
the tasktracker services running on all nodes in a Hadoop Cluster.
The jobtracker allocates work to the tasktracker nearest to the data
with an available work slot.

%package tasktracker
Summary: Hadoop Task Tracker
Group: System/Daemons
Requires: %{name} = %{version}-%{release}
Conflicts: hadoop-0.20-tasktracker
BuildArch: noarch

%description tasktracker
The tasktracker has a fixed number of work slots.  The jobtracker
assigns MapReduce work to the tasktracker that is nearest the data
with an available work slot.

%package -n hadoop-0.20-conf-pseudo
Summary: Hadoop installation in pseudo-distributed mode with MRv1
Group: System/Daemons
Requires: hadoop, hadoop-hdfs-namenode, hadoop-hdfs-datanode, hadoop-hdfs-secondarynamenode, %{name}-tasktracker = %{version}-%{release}, %{name}-jobtracker = %{version}-%{release}
Conflicts: hadoop-conf-pseudo

%description -n hadoop-0.20-conf-pseudo
Installation of this RPM will setup your machine to run in pseudo-distributed mode
where each Hadoop daemon runs in a separate Java process. You will be getting old
style daemons (MRv1) for Hadoop jobtracker and Hadoop tasktracker instead of new
YARN (MRv2) ones.

%prep
%setup -n hadoop-%{cloudera_version}

%build
# This assumes that you installed Java JDK 6 via RPM

/usr/bin/env -u DISPLAY \
  FULL_VERSION=%{cloudera_version} \
  JAVA_HOME="/usr/java/default" \
  DO_MAVEN_DEPLOY="" \
  SKIP_MVN_EXPLICIT="TRUE" \
  SKIP_EXTRA_NATIVE="TRUE" \
  sh -x %{SOURCE5}


%clean
%__rm -rf $RPM_BUILD_ROOT

#########################
#### INSTALL SECTION ####
#########################
%install

%__install -d -m 0755 $RPM_BUILD_ROOT/%{lib_hadoop}


bash -x %{SOURCE6} \
  --cloudera-source-dir=cloudera/files \
  --build-dir=%{hadoop_build_path} \
  --src-dir=$RPM_BUILD_ROOT%{src_hadoop} \
  --lib-dir=$RPM_BUILD_ROOT%{lib_hadoop} \
  --system-lib-dir=%{lib_hadoop}/lib/native \
  --system-include-dir=%{lib_hadoop}/include \
  --etc-dir=$RPM_BUILD_ROOT%{etc_hadoop} \
  --prefix=$RPM_BUILD_ROOT \
  --doc-dir=$RPM_BUILD_ROOT%{doc_hadoop} \
  --example-dir=$RPM_BUILD_ROOT%{doc_hadoop}/examples \
  --native-build-string=%{hadoop_arch} \
  --installed-lib-dir=%{lib_hadoop} \
  --man-dir=$RPM_BUILD_ROOT%{man_hadoop} \
  --apache-branch=%{apache_branch}

# Init.d scripts
%__install -d -m 0755 $RPM_BUILD_ROOT/%{initd_dir}/


%if  %{?suse_version:1}0
orig_init_file=$RPM_SOURCE_DIR/hadoop-init.tmpl.suse
%else
orig_init_file=$RPM_SOURCE_DIR/hadoop-init.tmpl
%endif

# Generate the init.d scripts
for service in %{hadoop_services}
do
       init_file=$RPM_BUILD_ROOT/%{initd_dir}/%{name}-${service}
       %__cp $orig_init_file $init_file
       %__sed -i -e 's|@HADOOP_COMMON_ROOT@|%{lib_hadoop}|' $init_file
       %__sed -i -e "s|@HADOOP_DAEMON@|${service}|" $init_file
       %__sed -i -e 's|@HADOOP_CONF_DIR@|%{config_hadoop}|' $init_file
       %__sed -i -e 's|@HADOOP_DAEMON_USER@|mapred|' $init_file

       chmod 755 $init_file
done
%__install -d -m 0755 $RPM_BUILD_ROOT/etc/default
%__cp $RPM_SOURCE_DIR/hadoop-0.20.default $RPM_BUILD_ROOT/etc/default/%{hadoop_name}-mapreduce

# /var/lib/hadoop/cache
%__install -d -m 1777 $RPM_BUILD_ROOT/var/lib/%{name}/cache
# /var/log/hadoop
%__install -d -m 0755 $RPM_BUILD_ROOT/var/log
%__install -d -m 0775 $RPM_BUILD_ROOT/var/run/%{name}
%__install -d -m 0775 $RPM_BUILD_ROOT/%{log_hadoop}

# Workaround for BIGTOP-583
rm -f $RPM_BUILD_ROOT/%{lib_hadoop}/lib/slf4j-log4j12-*.jar

# We need to link to the jar files provided by Hadoop 0.23 implementation
rm -f $RPM_BUILD_ROOT/%{lib_hadoop}/lib/{%{jar_deps_hadoop}}*.jar

# Install files for hadoop-0.20-conf-pseudo
%__install -d -m 0755 $RPM_BUILD_ROOT/%{etc_hadoop}/conf.pseudo.mr1
%__cp %{SOURCE7} %{SOURCE8} %{SOURCE9} %{SOURCE10} %{SOURCE11} %{SOURCE12} $RPM_BUILD_ROOT/%{etc_hadoop}/conf.pseudo.mr1
%__install -d -m 0755 $RPM_BUILD_ROOT/etc/security/limits.d
%__cp %{SOURCE13} $RPM_BUILD_ROOT/etc/security/limits.d
%__install -d -m 0755 $RPM_BUILD_ROOT/var/lib/hadoop/cache
%__install -d -m 0755 $RPM_BUILD_ROOT/var/lib/hdfs/cache

%pre
getent group mapred >/dev/null || groupadd -r mapred
getent passwd mapred >/dev/null || /usr/sbin/useradd --comment "Hadoop MapReduce" --shell /bin/bash -M -r -g mapred -G hadoop --home %{lib_hadoop} mapred

%preun
if [ "$1" = 0 ]; then
  # Stop any services that might be running
  for service in %{hadoop_services}
  do
     service %{name}-${service} stop 1>/dev/null 2>/dev/null || :
  done
fi

# Pseudo-distributed Hadoop installation
%post -n hadoop-0.20-conf-pseudo
%{alternatives_cmd} --install %{config_hadoop} hadoop-conf %{etc_hadoop}/conf.pseudo.mr1 30

%preun -n hadoop-0.20-conf-pseudo
if [ "$1" = 0 ]; then
        %{alternatives_cmd} --remove hadoop-conf %{etc_hadoop}/conf.pseudo.mr1
fi

%files -n hadoop-0.20-conf-pseudo
%defattr(-,root,root)
%config(noreplace) %attr(755,root,root) %{etc_hadoop}/conf.pseudo.mr1
%dir %attr(0755,root,hadoop) /var/lib/hadoop
%dir %attr(1777,root,hadoop) /var/lib/hadoop/cache
%dir %attr(0755,root,hdfs) /var/lib/hdfs
%dir %attr(1777,root,hdfs) /var/lib/hdfs/cache

%files
%defattr(-,root,root)
%config(noreplace) /etc/security/limits.d/mapred.conf
%config(noreplace) /etc/default/%{hadoop_name}-mapreduce
%attr(4754,root,mapred) %{lib_hadoop}/sbin/%{hadoop_arch}/task-controller
%{lib_hadoop}
%{lib_client}
%{bin_hadoop}/hadoop-0.20
%{man_hadoop}/man1/%{hadoop_name}.1.gz
%attr(0775,root,hadoop) /var/run/%{name}
%attr(0775,root,hadoop) %{log_hadoop}

# Service file management RPMs
%define service_macro() \
%files %1 \
%defattr(-,root,root) \
%{initd_dir}/%{name}-%1 \
%post %1 \
chkconfig --add %{name}-%1 \
\
%preun %1 \
if [ $1 = 0 ]; then \
  service %{name}-%1 stop > /dev/null 2>&1 \
  chkconfig --del %{name}-%1 \
fi \
%postun %1 \
if [ $1 -ge 1 ]; then \
  service %{name}-%1 condrestart >/dev/null 2>&1 \
fi
%service_macro jobtracker
%service_macro tasktracker
