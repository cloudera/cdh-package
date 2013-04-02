# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

##### HUE METAPACKAGE ######
Name:    hue
Version: %{hue_version}
Release: %{hue_release}
Group: Applications/Engineering
Summary: The hue metapackage
License: ASL 2.0
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id} -u -n)
Source0: %{name}-%{hue_patched_version}.tar.gz
Source1: %{name}.init
Source2: %{name}.init.suse
Source3: do-component-build
Source4: install_hue.sh
URL: http://github.com/cloudera/hue
Vendor: Cloudera, Inc.
Requires: hadoop
Requires: %{name}-plugins = %{version}-%{release}
Requires: %{name}-common = %{version}-%{release}
Requires: %{name}-filebrowser = %{version}-%{release}
Requires: %{name}-about = %{version}-%{release}
Requires: %{name}-help = %{version}-%{release}
Requires: %{name}-jobsub = %{version}-%{release}
Requires: %{name}-jobbrowser = %{version}-%{release}
Requires: %{name}-beeswax = %{version}-%{release}
Requires: %{name}-proxy = %{version}-%{release}
Requires: %{name}-shell = %{version}-%{release}
Requires: %{name}-oozie = %{version}-%{release}
Requires: %{name}-impala = %{version}-%{release}
# hue-user is a virtual package
Requires: %{name}-user

%description -n hue
Will install the entire set of hue and its plugins/applications

%files -n hue

%description
The hue metapackage, including hue-common and all hue applications.

##############################


################ RPM CUSTOMIZATION ##############################

# Disable automatic Provides generation - otherwise we will claim to provide all of the
# .so modules that we install inside our private lib directory, which will falsely
# satisfy dependencies for other RPMs on the target system.
AutoProv: no
AutoReqProv: no
%define _use_internal_dependency_generator 0

# Disable post hooks (brp-repack-jars, etc) that just take forever and sometimes cause issues
%define __os_install_post \
    %{!?__debug_package:/usr/lib/rpm/brp-strip %{__strip}} \
%{nil}
%define __jar_repack %{nil}
%define __prelink_undo_cmd %{nil}

# Disable debuginfo package, since we never need to gdb
# our own .sos anyway
%define debug_package %{nil}

# there are some file by-products we don't want to actually package
%define _unpackaged_files_terminate_build 0

# Init.d directory has different locations dependeing on the OS
%if  %{!?suse_version:1}0
%global initd_dir %{_sysconfdir}/rc.d/init.d
%else
%global initd_dir %{_sysconfdir}/rc.d
%endif


############### DESKTOP SPECIFIC CONFIGURATION ##################

# customization of install spots
%define hue_dir /usr/share/hue
%define hadoop_home /usr/lib/hadoop
%define hadoop_lib %{hadoop_home}/lib
%define username hue

%define apps_dir %{hue_dir}/apps
%define about_app_dir %{hue_dir}/apps/about
%define beeswax_app_dir %{hue_dir}/apps/beeswax
%define oozie_app_dir %{hue_dir}/apps/oozie
%define filebrowser_app_dir %{hue_dir}/apps/filebrowser
%define help_app_dir %{hue_dir}/apps/help
%define jobbrowser_app_dir %{hue_dir}/apps/jobbrowser
%define jobsub_app_dir %{hue_dir}/apps/jobsub
%define proxy_app_dir %{hue_dir}/apps/proxy
%define shell_app_dir %{hue_dir}/apps/shell
%define useradmin_app_dir %{hue_dir}/apps/useradmin
%define impala_app_dir %{hue_dir}/apps/impala

# Path to the HADOOP_HOME to build against - these
# are not substituted into the build products anywhere!
%if ! %{?build_hadoop_home:1} %{!?build_hadoop_home:0}
  %define build_hadoop_home %{hadoop_home}
%endif

# Post macro for apps
%define app_post_macro() \
%post -n %{name}-%1 \
export ROOT=%{hue_dir} \
export DESKTOP_LOGLEVEL=WARN \
export DESKTOP_LOG_DIR=/var/log/hue \
if [ "$1" != 1 ] ; then \
  echo %{hue_dir}/apps/%1 >> %{hue_dir}/.re_register \
fi \
%{hue_dir}/build/env/bin/python %{hue_dir}/tools/app_reg/app_reg.py --install %{apps_dir}/%1 \
(cd %{hue_dir} ; /bin/bash ./tools/relocatable.sh) \
chown -R hue:hue /var/log/hue \
chown hue:hue %{hue_dir}/desktop %{hue_dir}/desktop/desktop.db

# Preun macro for apps
%define app_preun_macro() \
%preun -n %{name}-%1 \
if [ "$1" = 0 ] ; then \
  export ROOT=%{hue_dir} \
  export DESKTOP_LOGLEVEL=WARN \
  export DESKTOP_LOG_DIR=/var/log/hue \
  if [[ -e $ENV_PYTHON && -f %{hue_dir}/tools/app_reg/app_reg.py ]] ; then \
    %{hue_dir}/build/env/bin/python %{hue_dir}/tools/app_reg/app_reg.py --remove %1 ||: \
  fi \
  find %{apps_dir}/%1 -name \*.egg-info -type f -print0 | xargs -0 /bin/rm -fR   \
fi \
find %{apps_dir}/%1 -iname \*.py[co] -type f -print0 | xargs -0 /bin/rm -f \
chown -Rf hue:hue /var/log/hue \
chown -f hue:hue %{hue_dir}/desktop %{hue_dir}/desktop/desktop.db ||:

%description
Hue is a browser-based desktop interface for interacting with Hadoop.
It supports a file browser, job tracker interface, cluster health monitor, and more.


%clean
%__rm -rf $RPM_BUILD_ROOT


%prep
%setup -n %{name}-%{hue_patched_version}

########################################
# Build
########################################
%build
bash -x %{SOURCE3}  

########################################
# Install
########################################
%install
bash -x %{SOURCE4} --prefix=$RPM_BUILD_ROOT --build-dir=${PWD}

%if  %{?suse_version:1}0
orig_init_file=$RPM_SOURCE_DIR/%{name}.init.suse
%else
orig_init_file=$RPM_SOURCE_DIR/%{name}.init
%endif

# TODO maybe dont need this line anymore:
%__install -d -m 0755 $RPM_BUILD_ROOT/%{initd_dir}
cp $orig_init_file $RPM_BUILD_ROOT/%{initd_dir}/hue

#### PLUGINS ######

%package -n %{name}-common
Summary: A browser-based desktop interface for Hadoop
BuildRequires: python-devel, python-setuptools, gcc, gcc-c++
BuildRequires: libxml2-devel, libxslt-devel, zlib-devel
BuildRequires: cyrus-sasl-devel
BuildRequires: openssl
#BuildRequires: hadoop, bigtop-utils
Group: Applications/Engineering
Requires: cyrus-sasl-gssapi, libxml2, libxslt, zlib, python, sqlite
Conflicts: cloudera-desktop
Provides: %{name}-common = %{version}, config(%{name}-common) = %{version}

%if  %{?suse_version:1}0
BuildRequires: sqlite3-devel, openldap2-devel, libmysqlclient-devel, libopenssl-devel
# Required for init scripts
Requires: insserv, python-xml
%else
BuildRequires: /sbin/runuser, sqlite-devel, openldap-devel, mysql-devel, openssl-devel
# Required for init scripts
Requires: redhat-lsb
%endif

# Disable automatic Provides generation - otherwise we will claim to provide all of the
# .so modules that we install inside our private lib directory, which will falsely
# satisfy dependencies for other RPMs on the target system.
AutoReqProv: no

%description -n %{name}-common
Hue is a browser-based desktop interface for interacting with Hadoop.
It supports a file browser, job tracker interface, cluster health monitor, and more.

########################################
# Preinstall
########################################
%pre -n %{name}-common -p /bin/bash
getent group %{username} 2>/dev/null >/dev/null || /usr/sbin/groupadd -r %{username}
getent passwd %{username} 2>&1 > /dev/null || /usr/sbin/useradd -c "Hue" -s /sbin/nologin -g %{username} -r -d %{hue_dir} %{username} 2> /dev/null || :

# If there is an old DB in place, make a backup.
if [ -e %{hue_dir}/desktop/desktop.db ]; then
  echo "Backing up previous version of Hue database..."
  cp -a %{hue_dir}/desktop/desktop.db %{hue_dir}/desktop/desktop.db.rpmsave.$(date +'%Y%m%d.%H%M%S')
fi

########################################
# FIXME: this is a workaround for RPM upgrade 
# sequence trying to change a subdiretory 
# into a symlink
########################################

if [ -e %{hue_dir}/desktop/logs ]; then
  NAME=%{hue_dir}/desktop/logs.$(date +'%Y%m%d.%H%M%S')
  echo "Preserving existing log files under $NAME"
  mv %{hue_dir}/desktop/logs %{hue_dir}/desktop/logs.$(date +'%Y%m%d.%H%M%S') || :
fi

########################################
# Post-uninstall
########################################
%postun -n %{name}-common -p /bin/bash

if [ -d %{hue_dir} ]; then
  find %{hue_dir} -name \*.py[co] -exec rm -f {} \;
fi

if [ $1 -eq 0 ]; then
  # TODO this seems awfully aggressive
  # NOTE  Despite dependency, hue-common could get removed before the apps are.
  #       We should remove app.reg because apps won't have a chance to
  #       unregister themselves.
  # FIXME: workaround for CDH-11067
  [ -e /usr/share/hue/desktop/desktop.db ] && ([ ! -e /var/lib/hue-db-backup ] && (install -d -o hue -g hue /var/lib/hue-db-backup || mkdir -p /var/lib/hue-db-backup) || true) && (umask 077; cp /usr/share/hue/desktop/desktop.db /var/lib/hue-db-backup/desktop.db.$(date +'%%Y%%m%%d.%%H%%M%%S')) || true
  rm -Rf %{hue_dir}/desktop %{hue_dir}/build %{hue_dir}/pids %{hue_dir}/app.reg
fi

%files -n %{name}-common
%defattr(-,root,root)
%attr(0755,root,root) %config(noreplace) /etc/hue/
%dir %{hue_dir}
%attr(0755,hue,hue) %{hue_dir}/desktop
%{hue_dir}/ext
%{hue_dir}/LICENSE.txt
%{hue_dir}/Makefile
%{hue_dir}/Makefile.buildvars
%{hue_dir}/Makefile.sdk
%{hue_dir}/Makefile.vars
%{hue_dir}/Makefile.vars.priv
%{hue_dir}/README
%{hue_dir}/tools
%{hue_dir}/VERSION
%{hue_dir}/build/env/bin/*
%{hue_dir}/build/env/include/
%{hue_dir}/build/env/lib*/
%{hue_dir}/build/env/stamp
%{hue_dir}/apps/Makefile
%{hue_dir}/cloudera/cdh_version.properties
%dir %{hue_dir}/apps
%attr(0755,root,root) %{initd_dir}/hue



%exclude %{hadoop_lib}

%exclude %{about_app_dir}
%exclude %{beeswax_app_dir}
%exclude %{oozie_app_dir}
%exclude %{filebrowser_app_dir}
%exclude %{help_app_dir}
%exclude %{jobbrowser_app_dir}
%exclude %{jobsub_app_dir}
%exclude %{proxy_app_dir}
%exclude %{useradmin_app_dir}
%exclude %{impala_app_dir}

%exclude %{shell_app_dir}


############################################################
# No-arch packages - plugins and conf
############################################################

#### Service Scripts ######
%package -n %{name}-server
Summary: Service Scripts for Hue
Requires: %{name}-common = %{version}-%{release}
Requires: /sbin/chkconfig
Requires(pre): %{name} = %{version}-%{release}
Group: Applications/Engineering

%description -n %{name}-server

This package provides the service scripts for Hue server.

%files -n %{name}-server
%attr(0755,root,root) %{initd_dir}/hue

# Install and start init scripts

%post -n %{name}  
/sbin/chkconfig --add hue

########################################
# Pre-uninstall
########################################

%preun  -n %{name}-server 
if [ $1 = 0 ] ; then 
        service %{name} stop > /dev/null 2>&1 
        chkconfig --del %{name} 
fi 
%postun  -n %{name}-server
if [ $1 -ge 1 ]; then 
        service %{name} condrestart >/dev/null 2>&1 
fi

#### PLUGINS ######
%package -n %{name}-plugins
Summary: Hadoop plugins for Hue
Requires: hadoop, bigtop-utils
Group: Applications/Engineering
Conflicts: cloudera-desktop-plugins
%description -n %{name}-plugins
Plugins for Hue

This package should be installed on each node in the Hadoop cluster.

%files -n %{name}-plugins
%defattr(-,root,root)
%{hadoop_lib}/
%{hadoop_home}/cloudera/



#### HUE-ABOUT PLUGIN ######
%package -n %{name}-about
Summary: Show version and configuration information about Hue
Group: Applications/Engineering
Requires: %{name}-common = %{version}-%{release}
Requires(pre): %{name}-common = %{version}-%{release}
Requires(preun): %{name}-common = %{version}-%{release}
Requires: make


%description -n %{name}-about
Displays the current version and configuration information about your Hue installation.

%app_post_macro about 
%app_preun_macro about 

%files -n %{name}-about
%defattr(-,root,root)
%{about_app_dir}




#### HUE-BEESWAX PLUGIN ######
%package -n %{name}-beeswax
Summary: A UI for Hive on Hue
Group: Applications/Engineering
Requires: make
Requires: %{name}-common = %{version}-%{release}
Requires(pre): %{name}-common = %{version}-%{release}
Requires(preun): %{name}-common = %{version}-%{release}
Requires: %{name}-jobbrowser = %{version}-%{release}
Requires: %{name}-filebrowser = %{version}-%{release}
Requires: %{name}-jobsub = %{version}-%{release}
Requires: %{name}-help = %{version}-%{release}
Requires: hive

%description -n %{name}-beeswax
Beeswax is a web interface for Hive.

It allows users to construct and run queries on Hive, manage tables,
and import and export data.

%app_post_macro beeswax
%app_preun_macro beeswax

%files -n %{name}-beeswax
%defattr(-,root,root)
%{beeswax_app_dir}

#### HUE-OOZIE PLUGIN ######
%package -n %{name}-oozie
Summary: A UI for Oozie on Hue
Group: Applications/Engineering
Requires: make
Requires: %{name}-common = %{version}-%{release}
Requires(pre): %{name}-common = %{version}-%{release}
Requires(preun): %{name}-common = %{version}-%{release}
Requires: %{name}-jobbrowser = %{version}-%{release}
Requires: %{name}-filebrowser = %{version}-%{release}
Requires: %{name}-jobsub = %{version}-%{release}
Requires: %{name}-help = %{version}-%{release}

%description -n %{name}-oozie
A web interface for Oozie.

It allows users to construct and run Oozie workflows without explicitly
managing the XML specification.

%app_post_macro oozie
%app_preun_macro oozie

%files -n %{name}-oozie
%defattr(-,root,root)
%{oozie_app_dir}

#### HUE-FILEBROWSER PLUGIN ######

%package -n %{name}-filebrowser
Summary: A UI for the Hadoop Distributed File System (HDFS)
Group: Applications/Engineering
Requires: make
Requires: %{name}-common = %{version}-%{release}
Requires(pre): %{name}-common = %{version}-%{release}
Requires(preun): %{name}-common = %{version}-%{release}
Requires: %{name}-help = %{version}-%{release}

%description -n %{name}-filebrowser
Filebrowser is a graphical web interface that lets you browse and interact with the Hadoop Distributed File System (HDFS).

%app_post_macro filebrowser
%app_preun_macro filebrowser

%files -n %{name}-filebrowser
%defattr(-,root,root)
%{filebrowser_app_dir}


#### HUE-HELP PLUGIN ######
%package -n %{name}-help
Summary: Display help documentation for various Hue apps
Group: Applications/Engineering
Requires: %{name}-common = %{version}-%{release}
Requires(pre): %{name}-common = %{version}-%{release}
Requires(preun): %{name}-common = %{version}-%{release}
Requires: make

%description -n %{name}-help
Displays help documentation for various Hue apps.

%app_post_macro help
%app_preun_macro help

%files -n %{name}-help
%defattr(-,root,root)
%{help_app_dir}


#### HUE-JOBBROWSER PLUGIN ######

%package -n %{name}-jobbrowser
Summary: A UI for viewing Hadoop map-reduce jobs
Group: Applications/Engineering
Requires: make
Requires: %{name}-common = %{version}-%{release}
Requires(pre): %{name}-common = %{version}-%{release}
Requires(preun): %{name}-common = %{version}-%{release}
Requires: %{name}-filebrowser = %{version}-%{release}
Requires: %{name}-help = %{version}-%{release}

%description -n %{name}-jobbrowser
Jobbrowser is a web interface for viewing Hadoop map-reduce jobs running on your cluster.

%app_post_macro jobbrowser
%app_preun_macro jobbrowser

%files -n %{name}-jobbrowser
%defattr(-,root,root)
%{jobbrowser_app_dir}


#### HUE-JOBSUB PLUGIN ######

%package -n %{name}-jobsub
Summary: A UI for designing and submitting map-reduce jobs to Hadoop
Group: Applications/Engineering
Requires: make
Requires: %{name}-common = %{version}-%{release}
Requires(pre): %{name}-common = %{version}-%{release}
Requires(preun): %{name}-common = %{version}-%{release}
Requires: %{name}-jobbrowser = %{version}-%{release}
Requires: %{name}-help = %{version}-%{release}

%description -n %{name}-jobsub
Jobsub is a web interface for designing and submitting map-reduce jobs to Hadoop.

%app_post_macro jobsub
%app_preun_macro jobsub

%files -n %{name}-jobsub
%defattr(-,root,root)
%{jobsub_app_dir}


#### HUE-PROXY PLUGIN ######

%package -n %{name}-proxy
Summary: Reverse proxy for the Hue server
Group: Applications/Engineering
Requires: make
Requires: %{name}-common = %{version}-%{release}
Requires(pre): %{name}-common = %{version}-%{release}
Requires(preun): %{name}-common = %{version}-%{release}

%description -n %{name}-proxy
Proxies HTTP requests through the Hue server. This is intended to be used for "built-in" UIs.

%app_post_macro proxy
%app_preun_macro proxy

%files -n %{name}-proxy
%defattr(-,root,root)
%{proxy_app_dir}


#### HUE-USERADMIN PLUGIN ######
%package -n %{name}-useradmin
Summary: Create/delete users, update user information
Group: Applications/Engineering
Provides: %{name}-user
Requires: make
Requires: %{name}-common = %{version}-%{release}
Requires(pre): %{name}-common = %{version}-%{release}
Requires(preun): %{name}-common = %{version}-%{release}
Requires: %{name}-filebrowser = %{version}-%{release}
Requires: %{name}-about = %{version}-%{release}
Requires: %{name}-help = %{version}-%{release}
Obsoletes: %{name}-userman

%description -n %{name}-useradmin
Create/delete Hue users, and update user information (name, email, superuser status, etc.)

%app_post_macro useradmin
%app_preun_macro useradmin

%files -n %{name}-useradmin
%defattr(-,root,root)
%{useradmin_app_dir}

#### HUE-IMPALA PLUGIN ######
%package -n %{name}-impala
Summary: A UI for Impala on Hue
Group: Applications/Engineering
Requires: make
Requires: %{name}-common = %{version}-%{release}
Requires(pre): %{name}-common = %{version}-%{release}
Requires(preun): %{name}-common = %{version}-%{release}
Requires: %{name}-jobbrowser = %{version}-%{release}
Requires: %{name}-filebrowser = %{version}-%{release}
Requires: %{name}-jobsub = %{version}-%{release}
Requires: %{name}-help = %{version}-%{release}

%description -n %{name}-impala
A web interface for Impala.

It allows users to construct and run queries on Impala, manage tables,
and import and export data.

%app_post_macro impala
%app_preun_macro impala

%files -n %{name}-impala
%defattr(-,root,root)
%{impala_app_dir}


############################################################
# Arch packages - plugins and conf
############################################################

#### HUE-PROXY PLUGIN ######
%package -n %{name}-shell
Summary: A shell for console based Hadoop applications
Group: Applications/Engineering
Requires: make
Requires: %{name}-common = %{version}-%{release}
Requires(pre): %{name}-common = %{version}-%{release}
Requires(preun): %{name}-common = %{version}-%{release}
Requires: %{name}-help = %{version}-%{release}

# Disable automatic Provides generation - otherwise we will claim to provide all of the
# .so modules that we install inside our private lib directory, which will falsely
# satisfy dependencies for other RPMs on the target system.
AutoReqProv: no

%description -n %{name}-shell
The Shell application lets the user connect to various backend shells (e.g. Pig, HBase, Flume).

%app_post_macro shell
%app_preun_macro shell

%files -n %{name}-shell
%defattr(-,root,root)
%{shell_app_dir}
%attr(4750,root,hue) %{shell_app_dir}/src/shell/build/setuid

