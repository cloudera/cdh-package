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
  %define alternatives_dep chkconfig
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
Source3: kudu-master.init
Source4: kudu-tserver.init
Requires: cyrus-sasl-lib
Requires: /usr/sbin/useradd, openssl
Requires(post): %{alternatives_dep}
Requires(preun): %{alternatives_dep}

%description
Columnar storage engine for Hadoop

%package master
Summary: Kudu Master service
Group: System/Daemons
Requires: %{name} = %{version}-%{release}

%description master
Kudu Master service

%package tserver
Summary: Kudu Tablet Server service
Group: System/Daemons
Requires: %{name} = %{version}-%{release}

%description tserver
Kudu Tablet Server service

%package client0
Summary: Kudu client library
Group: Development/Libraries
Requires: cyrus-sasl-lib

%description client0
Kudu client library

%package client-devel
Summary: Kudu client development package
Group: Development/Libraries
Requires: %{name}-client0 = %{version}-%{release}

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
          --system-include-dir=%{_includedir} \
          --system-lib-dir=%{_libdir} \
          --extra-dir=$RPM_SOURCE_DIR

# Install init scripts
init_source=$RPM_SOURCE_DIR
init_target=$RPM_BUILD_ROOT/%{initd_dir}
install -d -m 0755 $init_target
install -m 0755 $init_source/kudu-master.init $init_target/kudu-master
install -m 0755 $init_source/kudu-tserver.init $init_target/kudu-tserver
sed -i -e 's/@@CHKCONFIG@@/345 92 8/' \
    -e 's/@@DEFAULT_START@@/3 4 5/' \
    -e 's/@@DEFAULT_STOP@@/0 1 2 6/' \
    $init_target/kudu-master \
    $init_target/kudu-tserver

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
%{alternatives_cmd} --install /usr/lib/kudu/sbin kudu-sbin /usr/lib/kudu/sbin-release 30
%{alternatives_cmd} --install /usr/lib/kudu/sbin kudu-sbin /usr/lib/kudu/sbin-debug   20

%preun
if [ "$1" = 0 ]; then
    %{alternatives_cmd} --remove kudu-conf /etc/kudu/conf.dist || :
    %{alternatives_cmd} --remove kudu-bin /usr/lib/kudu/bin-release || :
    %{alternatives_cmd} --remove kudu-bin /usr/lib/kudu/bin-debug || :
    %{alternatives_cmd} --remove kudu-sbin /usr/lib/kudu/sbin-release || :
    %{alternatives_cmd} --remove kudu-sbin /usr/lib/kudu/sbin-debug || :
fi

%files
%defattr(-,root,root)
/usr/lib/kudu
/usr/bin/*
/usr/sbin/*
%attr(0755,kudu,kudu) %{kudu_log}
%attr(0755,kudu,kudu) %{kudu_run}
%attr(0755,kudu,kudu) %{kudu_lib}
# The %dir directive excludes files within conf.dist in the build tree from
# leaking into this package.
%attr(0755,root,root) %config(noreplace) %dir /etc/kudu/conf.dist
#%config(noreplace) /etc/security/limits.d/kudu.conf

%files client0
%{_libdir}/libkudu_client.so.*
%{_libdir}/debug/libkudu_client.so.*

%files client-devel
%{_libdir}/libkudu_client.so
%{_libdir}/debug/libkudu_client.so
/usr/include/kudu
%attr(0755,root,root) /usr/share/doc/kuduClient
%attr(0755,root,root) /usr/share/kuduClient

%changelog

%define service_macro() \
\
%files %1 \
%attr(0755,root,root)/%{initd_dir}/%2 \
%attr(0644,root,root) %config(noreplace) /etc/kudu/conf.dist/%1.gflagfile \
%attr(0644,root,root) %config(noreplace) /etc/default/%2 \
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

%service_macro master  kudu-master
%service_macro tserver kudu-tserver

