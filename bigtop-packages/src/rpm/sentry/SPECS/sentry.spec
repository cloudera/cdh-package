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

# disable repacking jars
%define __os_install_post %{nil}

%define var_lib_sentry /var/lib/sentry
%define var_run_sentry /var/run/sentry

%if  %{?suse_version:1}0
%global initd_dir %{_sysconfdir}/rc.d
%define alternatives_cmd update-alternatives
%else
%global initd_dir %{_sysconfdir}/rc.d/init.d
%define alternatives_cmd alternatives
%endif

Name: sentry
Version: %{sentry_version}
Release: %{sentry_release}
Summary: A system for enforcing fine grained role based authorization to data and metadata stored on a Hadoop cluster.
URL: https://sentry.incubator.apache.org
Group: Development/Libraries
BuildArch: noarch
Buildroot: %(mktemp -ud %{_tmppath}/%{datafu_name}-%{version}-%{release}-XXXXXX)
License: ASL 2.0
Source0: sentry-%{sentry_patched_version}.tar.gz
Source1: do-component-build
Source2: install_sentry.sh
Source3: init.d.tmpl
Source4: sentry-site.xml
Source5: sentry-store.svc
Source6: packaging_functions.sh
Source7: filter-requires.sh
Requires: hadoop-hdfs, hadoop-mapreduce, zookeeper, hive-jdbc >= 1.1.0+cdh5.4.0, hive >= 1.1.0+cdh5.4.0, hadoop-client >= 2.6.0+cdh5.4.0, solr >= 4.10.3+cdh5.5.1

%define _use_internal_dependency_generator 0
%define __find_requires %{SOURCE7} 'osgi'

%description
A system for enforcing fine grained role based authorization to data and metadata stored on a Hadoop cluster.

%package -n sentry-store
Summary: Sentry Server
Group: Development/Libraries
Requires: sentry = %{version}-%{release}

%description -n sentry-store
Server for Sentry

%package -n sentry-hdfs-plugin
Summary: Sentry HDFS plugin
Group: Development/Libraries
Requires: sentry = %{version}-%{release}, hadoop-hdfs

%description -n sentry-hdfs-plugin
Sentry HDFS plugin

%prep
%setup -n sentry-%{sentry_patched_version}

%build
env FULL_VERSION=%{sentry_patched_version} bash $RPM_SOURCE_DIR/do-component-build

%install
%__rm -rf $RPM_BUILD_ROOT
env FULL_VERSION=%{sentry_patched_version} bash $RPM_SOURCE_DIR/install_sentry.sh \
          --build-dir=$PWD \
          --prefix=$RPM_BUILD_ROOT \
          --extra-dir=$RPM_SOURCE_DIR

for service in sentry-store; do
    # Install init script
    init_file=$RPM_BUILD_ROOT/%{initd_dir}/${service}
    bash $RPM_SOURCE_DIR/init.d.tmpl $RPM_SOURCE_DIR/${service}.svc rpm $init_file
done

%pre
getent group sentry >/dev/null || groupadd -r sentry
getent passwd sentry >/dev/null || useradd -c "Sentry" -s /sbin/nologin -g sentry -r -d %{var_lib_sentry} sentry 2> /dev/null || :

%post
%{alternatives_cmd} --install /etc/sentry/conf senty-conf /etc/sentry/conf.dist 30

%preun
if [ "$1" = 0 ]; then
        %{alternatives_cmd} --remove sentry-conf /etc/sentry/conf.dist || :
fi

%define service_macro() \
%files -n %1 \
%attr(0755,root,root)/%{initd_dir}/%1 \
%post -n %1 \
chkconfig --add %1 \
\
%preun -n %1 \
if [ $1 = 0 ] ; then \
        service %1 stop > /dev/null 2>&1 \
        chkconfig --del %1 \
fi \
%postun -n %1 \
if [ $1 -ge 1 ]; then \
        service %1 condrestart >/dev/null 2>&1 \
fi
%service_macro sentry-store

%files
%defattr(-,root,root,755)
/usr/lib/hive/sentry
/usr/bin/sentry
/usr/lib/sentry
%exclude /usr/lib/sentry/lib/plugins
%config(noreplace) /etc/sentry/conf.dist
%defattr(-,sentry,sentry,755)
/var/lib/sentry
/var/log/sentry
/var/run/sentry

%files -n sentry-hdfs-plugin
%defattr(-,root,root,755)
/usr/lib/sentry/lib/plugins

