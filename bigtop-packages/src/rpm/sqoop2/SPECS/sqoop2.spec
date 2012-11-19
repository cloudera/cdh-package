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

%define lib_sqoop2 /usr/lib/sqoop2
%define conf_sqoop2 %{_sysconfdir}/%{name}/conf
%define conf_sqoop2_dist %{conf_sqoop2}.dist
%define run_sqoop2 /var/run/sqoop2

%if  %{?suse_version:1}0

# Only tested on openSUSE 11.4. le'ts update it for previous release when confirmed
%if 0%{suse_version} > 1130
%define suse_check \# Define an empty suse_check for compatibility with older sles
%endif

# SLES is more strict anc check all symlinks point to valid path
# But we do point to a conf which is not there at build time
# (but would be at install time).
# Since our package build system does not handle dependencies,
# these symlink checks are deactivated
%define __os_install_post \
    %{suse_check} ; \
    /usr/lib/rpm/brp-compress ; \
    %{nil}

%define doc_sqoop2 %{_docdir}/%{name}
%define initd_dir %{_sysconfdir}/rc.d
%define alternatives_cmd update-alternatives

%else

%define doc_sqoop2 %{_docdir}/%{name}-%{sqoop2_version}
%define initd_dir %{_sysconfdir}/rc.d/init.d
%define alternatives_cmd alternatives

%endif

Name: sqoop2
Version: %{sqoop2_version}
Release: %{sqoop2_release}
Summary:  Sqoop allows easy imports and exports of data sets between databases and the Hadoop Distributed File System (HDFS).
URL: http://incubator.apache.org/sqoop/
Group: Development/Libraries
Buildroot: %{_topdir}/INSTALL/%{name}-%{version}
License: APL2
Source0: %{name}-%{sqoop2_patched_version}.tar.gz
Source1: do-component-build
Source2: install_%{name}.sh
Source3: sqoop2.sh
Source4: sqoop.properties
Source5: catalina.properties
Source6: catalina.properties.mr1
Source7: setenv.sh
Source8: sqoop2-env.sh
Source9: init.d.tmpl
Buildarch: noarch
BuildRequires: asciidoc
Requires: hadoop-client, bigtop-utils

%description
Sqoop allows easy imports and exports of data sets between databases and the Hadoop Distributed File System (HDFS).

%package server
Summary: Server for Sqoop.
URL: http://incubator.apache.org/sqoop/
Group: System/Daemons
Requires: sqoop2 = %{version}-%{release}, bigtop-tomcat

%if  %{?suse_version:1}0
# Required for init scripts
Requires: insserv
%endif

%if  0%{?mgaversion}
# Required for init scripts
Requires: initscripts
%endif

# CentOS 5 does not have any dist macro
# So I will suppose anything that is not Mageia or a SUSE will be a RHEL/CentOS/Fedora
%if %{!?suse_version:1}0 && %{!?mgaversion:1}0
# Required for init scripts
Requires: redhat-lsb
%endif

%description server
Centralized server for Sqoop.

%prep
%setup -n sqoop2-%{sqoop2_patched_version}

%build
# No easy way to disable the default RAT run which fails the build because of some fails in the debian/ directory
rm -rf bigtop-empty
mkdir -p bigtop-empty
# I could not find a way to add debian/ to RAT exclude list through cmd line
# or to unbind rat:check goal
# So I am redirecting its attention with a decoy
env FULL_VERSION=%{sqoop2_patched_version} bash %{SOURCE1} -Drat.basedir=${PWD}/bigtop-empty

%install
%__rm -rf $RPM_BUILD_ROOT
sh %{SOURCE2} \
          --build-dir=build/sqoop2-%{sqoop2_patched_version} \
          --conf-dir=%{conf_sqoop2_dist} \
          --doc-dir=%{doc_sqoop2} \
          --prefix=$RPM_BUILD_ROOT \
          --extra-dir=$RPM_SOURCE_DIR \
          --initd-dir=%{initd_dir}

# Install init script
init_file=$RPM_BUILD_ROOT/%{initd_dir}/%{name}-server
bash $RPM_SOURCE_DIR/init.d.tmpl $RPM_SOURCE_DIR/%{name}-server.svc rpm $init_file

%__install -d -m 0755 $RPM_BUILD_ROOT/usr/bin
%__install -d  -m 0755 $RPM_BUILD_ROOT/var/lib/sqoop2

%pre
getent group sqoop >/dev/null || groupadd -r sqoop
getent passwd sqoop >/dev/null || useradd -c "Sqoop User" -s /sbin/nologin -g sqoop -r -d %{run_sqoop2} sqoop 2> /dev/null || :
%__install -d -o sqoop -g sqoop -m 0755 /var/lib/sqoop2
%__install -d -o sqoop -g sqoop -m 0755 /var/log/sqoop2

%post server
%{alternatives_cmd} --install %{conf_sqoop2} %{name}-conf %{conf_sqoop2_dist} 30
chkconfig --add sqoop2-server

%preun server
if [ "$1" = "0" ] ; then
  service sqoop2-server stop > /dev/null 2>&1
  chkconfig --del sqoop2-server
  %{alternatives_cmd} --remove %{name}-conf %{conf_sqoop2_dist} || :
fi

%postun server
if [ $1 -ge 1 ]; then
  service sqoop2-server condrestart > /dev/null 2>&1
fi

# Files for client package
%files
%attr(0755,root,root) /usr/bin/sqoop2
%attr(0755,root,root) %{lib_sqoop2}/bin/sqoop.sh
%defattr(0644,root,root)
%{lib_sqoop2}
/etc/sqoop2/conf.dist/*
/var/lib/sqoop2
/var/tmp/sqoop2

%files server
%attr(0755,root,root) %{initd_dir}/sqoop2-server

