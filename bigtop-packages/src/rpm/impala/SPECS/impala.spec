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
#%define man_dir %{_mandir}
#
#%if  %{?suse_version:1}0
#%define bin_jsvc /usr/lib/bigtop-utils
#%define doc_jsvc %{_docdir}/%{name}
#%else
#%define bin_jsvc %{_libexecdir}/bigtop-utils
#%define doc_jsvc %{_docdir}/%{name}-%{bigtop_jsvc_version}
#%endif

# FIXME: brp-repack-jars uses unzip to expand jar files
# Unfortunately aspectjtools-1.6.5.jar pulled by ivy contains some files and directories without any read permission
# and make whole process to fail.
# So for now brp-repack-jars is being deactivated until this is fixed.
# See BIGTOP-294
%if  %{!?suse_version:1}0
%define __os_install_post \
    /usr/lib/rpm/redhat/brp-compress ; \
    /usr/lib/rpm/redhat/brp-strip-static-archive %{__strip} ; \
    /usr/lib/rpm/redhat/brp-strip-comment-note %{__strip} %{__objdump} ; \
    /usr/lib/rpm/brp-python-bytecompile ; \
    %{nil}
%else
%define __os_install_post \
    %{suse_check} ; \
    /usr/lib/rpm/brp-compress ; \
    %{nil}
%endif

%undefine _missing_build_ids_terminate_build

%define impala_log /var/log/impala
%define impala_run /var/run/impala
%define impala_lib /var/lib/impala

%if  %{!?suse_version:1}0
  %define initd_dir %{_sysconfdir}/rc.d/init.d
  %define alternatives_cmd alternatives
  %define alternatives_dep chkconfig
%else
  %define initd_dir %{_sysconfdir}/rc.d
  %define alternatives_cmd update-alternatives
  %define alternatives_dep update-alternatives
%endif

Name: impala
Version: %{impala_version}
Release: %{impala_release}
Summary: Application for executing real-time queries on top of Hadoop
URL: http://www.cloudera.com
Group: Development/Libraries
Buildroot: %{_topdir}/INSTALL/%{name}-%{version}
License: ASL 2.0
Source0: impala-%{impala_patched_version}.tar.gz
Source1: do-component-build
Source2: install_impala.sh
Source3: filter-requires.sh
Source4: init.d.tmpl
Source5: impala.conf
Source6: impalad.svc
Source7: statestored.svc
Source8: catalogd.svc
Requires: bigtop-utils >= 0.7, /usr/sbin/useradd, /usr/sbin/usermod, openssl
Requires: hadoop, hadoop-hdfs, hadoop-yarn, hadoop-mapreduce, hbase, hive, zookeeper, hadoop-libhdfs
Requires: avro-libs, parquet
%if %{!?suse_version:1}0 && %{!?mgaversion:1}0
Requires: redhat-lsb
%else
Requires: libopenssl0_9_8
%endif
BuildRequires: ant, cmake, gcc
Requires(post): %{alternatives_dep}
Requires(preun): %{alternatives_dep}

%define    _use_internal_dependency_generator 0
%define    __find_requires %{SOURCE3}

%description 
Application for executing real-time queries on top of Hadoop

%package udf-devel
Summary: Impala UDF development package
Group: Development/Libraries

%description udf-devel
Development headers and libraries for writing user-defined-functions for Impala queries

%package shell
Summary: Impala shell
Group: Development/Libraries
%if  %{!?suse_version:1}0
Requires: python, python-setuptools
%else
Requires: python
%endif
BuildRequires: gcc-c++, cyrus-sasl-devel, python-devel, python-setuptools

%description shell
Impala shell

%package server
Summary: Impala server
Group: System/Daemons
Requires: %{name} = %{version}-%{release}

%description server
Impala server

%package state-store
Summary: Impala State Store server
Group: System/Daemons
Requires: %{name} = %{version}-%{release}

%description state-store
Impala State Store server

%package catalog
Summary: Impala Catalog server
Group: System/Daemons
Requires: %{name} = %{version}-%{release}

%description catalog
Impala Catalog server

# use the debug_package macro if needed
%if  %{!?suse_version:1}0
# RedHat does this by default
%else
%debug_package
%endif

%prep
%setup -n %{name}-%{impala_patched_version}

%clean
rm -rf $RPM_BUILD_ROOT

%build
env FULL_VERSION=%{impala_patched_version} bash %{SOURCE1}

%install
%__rm -rf $RPM_BUILD_ROOT
sh %{SOURCE2} \
          --build-dir=$RPM_SOURCE_DIR \
          --prefix=$RPM_BUILD_ROOT \
          --native-lib-dir=lib64 \
          --system-include-dir=%{_includedir} \
          --system-lib-dir=%{_libdir}

# Install init scripts
init_source=$RPM_SOURCE_DIR
init_target=$RPM_BUILD_ROOT/%{initd_dir}
bash $init_source/init.d.tmpl $init_source/impalad.svc rpm $init_target/impala-server
bash $init_source/init.d.tmpl $init_source/statestored.svc rpm $init_target/impala-state-store
bash $init_source/init.d.tmpl $init_source/catalogd.svc rpm $init_target/impala-catalog

# Install security limits
%__install -d -m 0755 $RPM_BUILD_ROOT/etc/security/limits.d
%__install -m 0644 %{SOURCE5} $RPM_BUILD_ROOT/etc/security/limits.d/impala.conf

%pre
getent group impala >/dev/null || groupadd -r impala
getent group hive >/dev/null || groupadd -r hive
getent group hdfs >/dev/null || groupadd -r hdfs
getent passwd impala >/dev/null || /usr/sbin/useradd --comment "Impala" --shell /bin/bash -M -r -g impala -G hive,hdfs --home %{impala_run} impala

%post
%{alternatives_cmd} --install /etc/impala/conf impala-conf /etc/impala/conf.dist        30
%{alternatives_cmd} --install /usr/lib/impala/sbin %{name} /usr/lib/impala/sbin-retail  20
%{alternatives_cmd} --install /usr/lib/impala/sbin %{name} /usr/lib/impala/sbin-debug   10

%preun
if [ "$1" = 0 ]; then
    %{alternatives_cmd} --remove impala-conf /etc/impala/conf.dist || :
    %{alternatives_cmd} --remove %{name} /usr/lib/impala/sbin-retail || :
    %{alternatives_cmd} --remove %{name} /usr/lib/impala/sbin-debug || :
fi

%post udf-devel
%{alternatives_cmd} --install %{_libdir}/libImpalaUdf.a libImpalaUdf %{_libdir}/libImpalaUdf-retail.a  20
%{alternatives_cmd} --install %{_libdir}/libImpalaUdf.a libImpalaUdf %{_libdir}/libImpalaUdf-debug.a 10

%preun udf-devel
if [ "$1" = 0 ]; then
    %{alternatives_cmd} --remove libImpalaUdf %{_libdir}/libImpalaUdf-retail.a || :
    %{alternatives_cmd} --remove libImpalaUdf %{_libdir}/libImpalaUdf-debug.a || :
fi

%files udf-devel
%defattr(-,root,root)
%{_includedir}/impala_udf
%{_libdir}/libImpalaUdf*.a

%files shell
%defattr(-,root,root)
/usr/lib/impala-shell
/usr/bin/impala-shell

%files
%defattr(-,root,root)
/usr/lib/impala
/usr/bin/statestored
/usr/bin/impalad
/usr/bin/catalogd
%attr(0755,impala,impala) %{impala_log}
%attr(0755,impala,impala) %{impala_run}
%attr(0755,impala,impala) %{impala_lib}
%attr(0755,root,root) %config(noreplace) /etc/impala/conf.dist
%attr(0644,root,root) %config(noreplace) /etc/default/impala
%config(noreplace) /etc/security/limits.d/impala.conf

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

%service_macro server      impala-server
%service_macro state-store impala-state-store
%service_macro catalog     impala-catalog

