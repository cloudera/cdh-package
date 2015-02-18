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

%define kudu_log /var/log/kudu
%define kudu_run /var/run/kudu
%define kudu_lib /var/lib/kudu

%if  %{!?suse_version:1}0
  %define initd_dir %{_sysconfdir}/rc.d/init.d
  %define alternatives_cmd alternatives
  %define alternatives_dep chkconfig
%else
  %define initd_dir %{_sysconfdir}/rc.d
  %define alternatives_cmd update-alternatives
  %define alternatives_dep update-alternatives
%endif

Name: kudu
Version: %{kudu_version}
Release: %{kudu_release}
Summary: Columnar storage engine for Hadoop
URL: http://www.cloudera.com
Group: Development/Libraries
Buildroot: %{_topdir}/INSTALL/%{name}-%{version}
License: ASL 2.0
Source0: kudu-%{kudu_patched_version}.tar.gz
Source1: do-component-build
Source2: install_kudu.sh
Source3: init.d.tmpl
Source4: kudu-master.svc
Source5: kudu-tablet-server.svc
Source6: packaging_functions.sh
Requires: /usr/sbin/useradd
Requires(post): %{alternatives_dep}
Requires(preun): %{alternatives_dep}

%description
Columnar storage engine for Hadoop

%package master
Summary: Kudu master service
Group: System/Daemons
Requires: %{name} = %{version}-%{release}

%description master
Kudu master service

%package tablet-server
Summary: Kudu tablet-server service
Group: System/Daemons
Requires: %{name} = %{version}-%{release}

%description tablet-server
Kudu tablet-server service

%package client
Summary: Kudu client library
Group: Development/Libraries

%description client
Kudu client library

%package client-devel
Summary: Kudu client development package
Group: Development/Libraries
Requires: %{name}-client = %{version}-%{release}

%description client-devel
Kudu client development package

# use the debug_package macro if needed
%if  %{!?suse_version:1}0
# RedHat does this by default
%else
%debug_package
%endif

%prep
%setup -n %{name}-%{kudu_patched_version}

%clean
rm -rf $RPM_BUILD_ROOT

%build
env FULL_VERSION=%{kudu_patched_version} bash %{SOURCE1}

%install
%__rm -rf $RPM_BUILD_ROOT
bash %{SOURCE2} \
          --build-dir=$PWD \
          --prefix=$RPM_BUILD_ROOT \
          --native-lib-dir=lib64 \
          --system-include-dir=%{_includedir} \
          --system-lib-dir=%{_libdir} \
          --extra-dir=$RPM_SOURCE_DIR

# Install init scripts
init_source=$RPM_SOURCE_DIR
init_target=$RPM_BUILD_ROOT/%{initd_dir}
bash $init_source/init.d.tmpl $init_source/kudu-master.svc rpm $init_target/kudu-master
bash $init_source/init.d.tmpl $init_source/kudu-tablet-server.svc rpm $init_target/kudu-tablet-server

# Install security limits
#%__install -d -m 0755 $RPM_BUILD_ROOT/etc/security/limits.d
#%__install -m 0644 %{SOURCE5} $RPM_BUILD_ROOT/etc/security/limits.d/kudu.conf

%pre
getent group kudu >/dev/null || groupadd -r kudu
getent passwd kudu >/dev/null || /usr/sbin/useradd --comment "Kudu" --shell /bin/bash -M -r -g kudu --home %{kudu_lib} kudu

%post
%{alternatives_cmd} --install /etc/kudu/conf kudu-conf /etc/kudu/conf.dist         30
%{alternatives_cmd} --install /usr/lib/kudu/bin kudu-bin /usr/lib/kudu/bin-release 30
%{alternatives_cmd} --install /usr/lib/kudu/bin kudu-bin /usr/lib/kudu/bin-debug   20

%preun
if [ "$1" = 0 ]; then
    %{alternatives_cmd} --remove kudu-conf /etc/kudu/conf.dist || :
    %{alternatives_cmd} --remove kudu-bin /usr/lib/kudu/bin-release || :
    %{alternatives_cmd} --remove kudu-bin /usr/lib/kudu/bin-debug || :
fi

%files
%defattr(-,root,root)
/usr/lib/kudu
/usr/bin/*
%attr(0755,kudu,kudu) %{kudu_log}
%attr(0755,kudu,kudu) %{kudu_run}
%attr(0755,kudu,kudu) %{kudu_lib}
%attr(0755,root,root) %config(noreplace) /etc/kudu/conf.dist
%attr(0644,root,root) %config(noreplace) /etc/default/kudu
#%config(noreplace) /etc/security/limits.d/kudu.conf

%files client
%{_libdir}/libkudu*.so

%files client-devel
/usr/include/kudu
%attr(0755,root,root) /usr/share/doc/kuduClient
%attr(0755,root,root) /usr/share/kuduClient

%changelog

%define service_macro() \
\
%files %1 \
%attr(0755,root,root)/%{initd_dir}/%2 \
\
%post %1 \
chkconfig --add %2 \
\
%preun %1 \
if [ "$1" = 0 ] ; then \
    service %2 stop > /dev/null \
    chkconfig --del %2 \
fi \
\
%postun %1 \
if [ $1 -ge 1 ]; then \
    service %2 condrestart >/dev/null 2>&1 || : \
fi

%service_macro master        kudu-master
%service_macro tablet-server kudu-tablet-server

