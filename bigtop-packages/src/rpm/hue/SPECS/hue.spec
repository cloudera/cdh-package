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
Requires: %{name}-pig = %{version}-%{release}
Requires: %{name}-metastore = %{version}-%{release}
Requires: %{name}-hbase = %{version}-%{release}
Requires: %{name}-sqoop = %{version}-%{release}
Requires: %{name}-search = %{version}-%{release}
# hue-user is a virtual package
Requires: %{name}-user

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
%define alternatives_cmd alternatives
%global initd_dir %{_sysconfdir}/rc.d/init.d
%else
%define alternatives_cmd update-alternatives
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
%define pig_app_dir %{hue_dir}/apps/pig
%define metastore_app_dir %{hue_dir}/apps/metastore
%define filebrowser_app_dir %{hue_dir}/apps/filebrowser
%define help_app_dir %{hue_dir}/apps/help
%define jobbrowser_app_dir %{hue_dir}/apps/jobbrowser
%define jobsub_app_dir %{hue_dir}/apps/jobsub
%define proxy_app_dir %{hue_dir}/apps/proxy
%define shell_app_dir %{hue_dir}/apps/shell
%define useradmin_app_dir %{hue_dir}/apps/useradmin
%define etc_hue /etc/hue/conf 
%define impala_app_dir %{hue_dir}/apps/impala
%define hbase_app_dir %{hue_dir}/apps/hbase
%define sqoop_app_dir %{hue_dir}/apps/sqoop
%define search_app_dir %{hue_dir}/apps/search

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
chown -R hue:hue /var/log/hue /var/lib/hue

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
chown -R hue:hue /var/log/hue /var/lib/hue || :

%description
Hue is a browser-based desktop interface for interacting with Hadoop.
It supports a file browser, job tracker interface, cluster health monitor, and more.

%files -n hue

%clean
%__rm -rf $RPM_BUILD_ROOT

%prep
%setup -n %{name}-%{hue_patched_version}

########################################
# Build
########################################
%build

if [ -f /etc/redhat-release ] ; then
    if grep 5\\. /etc/redhat-release ; then
        # RHEL 5 slaves have both Python 2.4 and Python 2.6, and CDH 4 needs to use Python 2.4
        export SYS_PYTHON=`which python2.4`
        export SKIP_PYTHONDEV_CHECK=true
    fi
fi

bash -x %{SOURCE3}  

########################################
# Install
########################################
%install

if [ -f /etc/redhat-release ] ; then
    if grep 5\\. /etc/redhat-release ; then
        # RHEL 5 slaves have both Python 2.4 and Python 2.6, and CDH 4 needs to use Python 2.4
        export SYS_PYTHON=`which python2.4`
        export SKIP_PYTHONDEV_CHECK=true
    fi
fi

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
BuildRequires: krb5-devel
Group: Applications/Engineering
Requires: cyrus-sasl-gssapi, libxml2, libxslt, zlib, python, sqlite
# The only reason we need the following is because we also have AutoProv: no
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

OLD_DESKTOP_DB=/usr/share/hue/desktop/desktop.db
OLD_APP_REG=/usr/share/hue/app.reg
OLD_PTH_FILE=`echo /usr/share/hue/build/env/lib/python*/site-packages/hue.pth | cut -f1 -d\  `
VAR_LIB=/var/lib/hue

# Seeding mutable files
mkdir -p ${VAR_LIB} || :
for mfile in ${OLD_DESKTOP_DB} ${OLD_APP_REG} ${OLD_PTH_FILE} ; do
  if [ ! -e ${VAR_LIB}/`basename $mfile` -a -e $mfile ] ; then
    cp $mfile ${VAR_LIB} || :
  fi
done

# If there is an old DB in place, make a backup.
if [ -e %{hue_dir}/desktop/desktop.db ]; then
  echo "Backing up previous version of Hue database..."
  cp -a %{hue_dir}/desktop/desktop.db %{hue_dir}/desktop/desktop.db.rpmsave.$(date +'%Y%m%d.%H%M%S')
fi

# Ditto for logs
if [ -e %{hue_dir}/desktop/logs ]; then
  NAME=%{hue_dir}/desktop/logs.$(date +'%Y%m%d.%H%M%S')
  echo "Preserving existing log files under $NAME"
  mv %{hue_dir}/desktop/logs %{hue_dir}/desktop/logs.$(date +'%Y%m%d.%H%M%S') || :
fi

########################################
# FIXME: this is a workaround for RPM upgrade 
# sequence trying to change a subdiretory 
# into a symlink
########################################
%post -n %{name}-common -p /bin/bash

%{alternatives_cmd} --install %{etc_hue} hue-conf /etc/hue 30

export DESKTOP_LOGLEVEL=WARN
export DESKTOP_LOG_DIR=/var/log/hue
mkdir -p $DESKTOP_LOG_DIR || :
/usr/share/hue/build/env/bin/hue syncdb --noinput

# initialize seed databases if there's none
chown -R hue:hue /var/log/hue /var/lib/hue

%preun -n %{name}-common -p /bin/bash
if [ "$1" = 0 ]; then
        %{alternatives_cmd} --remove hue-conf /etc/hue || :
fi

########################################
# Post-uninstall
########################################
%postun -n %{name}-common -p /bin/bash

if [ -d %{hue_dir} ]; then
  find %{hue_dir} -name \*.py[co] -exec rm -f {} \;
fi

##################################################
# Post-transaction (runs when old package is gone)
##################################################
%posttrans -n %{name}-common -p /bin/bash
# This is only here because post-rm scripts of previous
# package could have removed the convenience links
(VAR_DIR=/var/lib/hue
 ln -s ${VAR_DIR}/desktop.db %{hue_dir}/desktop/desktop.db
 ln -s ${VAR_DIR}/app.reg %{hue_dir}/app.reg
 ln -s ${VAR_DIR}/hue.pth `echo %{hue_dir}/build/env/lib/python*/site-packages`/hue.pth) >/dev/null 2>&1 || :

%files -n %{name}-common
%defattr(-,root,root)
%attr(0755,root,root) %config(noreplace) /etc/hue/
%dir %{hue_dir}
%{hue_dir}/desktop
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
%{hue_dir}/app.reg
%{hue_dir}/apps/Makefile
%{hue_dir}/cloudera/cdh_version.properties
%dir %{hue_dir}/apps
%attr(0755,%{username},%{username}) /var/log/hue
%attr(0755,%{username},%{username}) /var/lib/hue


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
%exclude %{pig_app_dir}
%exclude %{metastore_app_dir}
%exclude %{hbase_app_dir}
%exclude %{sqoop_app_dir}
%exclude %{search_app_dir}

%exclude %{shell_app_dir}


############################################################
# No-arch packages - plugins and conf
############################################################

#### Service Scripts ######
%package -n %{name}-server
Summary: Service Scripts for Hue
Requires: %{name}-common = %{version}-%{release}
Requires(pre): %{name}-common = %{version}-%{release}
Requires(preun): %{name}-common = %{version}-%{release}
Requires: /sbin/chkconfig
Group: Applications/Engineering

%description -n %{name}-server

This package provides the service scripts for Hue server.

%files -n %{name}-server
%attr(0755,root,root) %{initd_dir}/hue

# Install and start init scripts

%post -n %{name}-server 
/sbin/chkconfig --add hue

# Documentation
%package -n %{name}-doc
Summary: Documentation for Hue
Group: Documentation

%description -n %{name}-doc
This package provides the installation manual, user guide, SDK documentation, and release notes.

%files -n %{name}-doc
%attr(0755,root,root) /usr/share/doc/hue

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
Requires: %{name}-metastore = %{version}-%{release}
Requires: hive
Requires: cyrus-sasl-plain

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
Requires: %{name}-help = %{version}-%{release}
Requires: %{name}-jobsub = %{version}-%{release}

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
Requires: %{name}-oozie = %{version}-%{release}
Requires(pre): %{name}-oozie = %{version}-%{release}
Requires(preun): %{name}-oozie = %{version}-%{release}
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
Requires: %{name}-metastore = %{version}-%{release}

%description -n %{name}-impala
A web interface for Impala.

It allows users to construct and run queries on Impala, manage tables,
and import and export data.

%app_post_macro impala
%app_preun_macro impala

%files -n %{name}-impala
%defattr(-,root,root)
%{impala_app_dir}

#### HUE-PIG PLUGIN ######
%package -n %{name}-pig
Summary: A UI for Pig on Hue
Group: Applications/Engineering
Requires: %{name}-common = %{version}-%{release}
Requires(pre): %{name}-common = %{version}-%{release}
Requires(preun): %{name}-common = %{version}-%{release}

%description -n %{name}-pig
A web interface for Pig.

It allows users to construct and run Pig jobs.

%app_post_macro pig
%app_preun_macro pig

%files -n %{name}-pig
%{pig_app_dir}

#### HUE-METASTORE PLUGIN ######
%package -n %{name}-metastore
Summary: A UI for table metastore on Hue
Group: Applications/Engineering
Requires: %{name}-common = %{version}-%{release}
Requires(pre): %{name}-common = %{version}-%{release}
Requires(preun): %{name}-common = %{version}-%{release}

%description -n %{name}-metastore
A web interface to table metastore.

%app_post_macro metastore
%app_preun_macro metastore

%files -n %{name}-metastore
%{metastore_app_dir}

#### HUE-HBASE PLUGIN ######
%package -n %{name}-hbase
Summary: A UI for HBase on Hue
Group: Applications/Engineering
Requires: %{name}-common = %{version}-%{release}
Requires(pre): %{name}-common = %{version}-%{release}
Requires(preun): %{name}-common = %{version}-%{release}

%description -n %{name}-hbase
A web interface for HBase.

It allows users to construct and run HBase queries.

%app_post_macro hbase
%app_preun_macro hbase

%files -n %{name}-hbase
%{hbase_app_dir}

#### HUE-SQOOP PLUGIN ######
%package -n %{name}-sqoop
Summary: A UI for Sqoop on Hue
Group: Applications/Engineering
Requires: %{name}-common = %{version}-%{release}
Requires(pre): %{name}-common = %{version}-%{release}
Requires(preun): %{name}-common = %{version}-%{release}

%description -n %{name}-sqoop
A web interface for Sqoop.

%app_post_macro sqoop
%app_preun_macro sqoop

%files -n %{name}-sqoop
%{sqoop_app_dir}

#### HUE-SEARCH PLUGIN ######
%package -n %{name}-search
Summary: A UI for Search on Hue
Group: Applications/Engineering
Requires: %{name}-common = %{version}-%{release}, %{name}-user = %{version}-%{release}, %{name}-about = %{version}-%{release}, %{name}-help = %{version}-%{release}
Requires(pre): %{name}-common = %{version}-%{release}
Requires(preun): %{name}-common = %{version}-%{release}

%description -n %{name}-search
A web interface for Search.

It allows users to interact with Solr

%app_post_macro search
%app_preun_macro search

%files -n %{name}-search
%{search_app_dir}

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

