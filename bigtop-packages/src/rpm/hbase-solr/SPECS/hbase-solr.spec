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

%define solr_name hbase-solr
%define lib_solr /usr/lib/%{solr_name}
%define etc_solr /etc/%{solr_name}
%define config_solr %{etc_solr}/conf
%define log_solr /var/log/%{solr_name}
%define bin_solr /usr/bin
%define man_dir /usr/share/man
%define run_solr /var/run/%{solr_name}
%define state_solr /var/lib/%{solr_name}
%define svc_solr %{name}-indexer
%define user_solr hbase 

%if  %{?suse_version:1}0
%define doc_solr %{_docdir}/hbase-solr-doc
%define alternatives_cmd update-alternatives
%define chkconfig_dep    aaa_base
%define service_dep      aaa_base
%global initd_dir %{_sysconfdir}/rc.d
%else
%define doc_solr %{_docdir}/hbase-solr-doc-%{hbase_solr_version}
%define alternatives_cmd alternatives
%define chkconfig_dep    chkconfig
%define service_dep      initscripts
%global initd_dir %{_sysconfdir}/rc.d/init.d
%endif

# disable repacking jars
%define __os_install_post %{nil}

Name: hbase-solr
Version: %{hbase_solr_version}
Release: %{hbase_solr_release}
Summary: Apache Solr is the popular, blazing fast open source enterprise search platform
URL: http://lucene.apache.org/solr
Group: Development/Libraries
BuildArch: noarch
Buildroot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
License: ASL 2.0
Source0: hbase-solr-%{hbase_solr_patched_version}.tar.gz
Source1: do-component-build 
Source2: install_hbase_solr.sh
Source3: init.d.tmpl
Source4: hbase-solr-indexer.svc
Source5: packaging_functions.sh
Source6: filter-requires.sh
Requires: bigtop-utils >= 0.7, hbase, solr, hadoop-client
Requires: avro-libs, parquet, sentry >= 1.3.0+cdh5.1.0, search, kite >= 0.10.0+cdh5.1.0, hadoop-hdfs, hadoop, zookeeper, hadoop-0.20-mapreduce, solr-mapreduce >= 1.0.0+cdh5.4.0

# CentOS 5 does not have any dist macro
# So I will suppose anything that is not Mageia or a SUSE will be a RHEL/CentOS/Fedora
%if %{!?suse_version:1}0 && %{!?mgaversion:1}0
# Required for init scripts
Requires: /lib/lsb/init-functions
%endif

%define _use_internal_dependency_generator 0
%define __find_requires %{SOURCE6} 'osgi'

%description 
Solr is written in Java and runs as a standalone full-text search server within
a servlet container such as Tomcat. Solr uses the Lucene Java search library at
its core for full-text indexing and search, and has REST-like HTTP/XML and JSON
APIs that make it easy to use from virtually any programming language. Solr's
powerful external configuration allows it to be tailored to almost any type of
application without Java coding, and it has an extensive plugin architecture
when more advanced customization is required.

%package indexer
Summary: The Solr server
Group: System/Daemons
Requires: %{name} = %{version}-%{release}
Requires(post): %{chkconfig_dep}
Requires(preun): %{service_dep}, %{chkconfig_dep}
BuildArch: noarch

%description indexer
This package starts the Solr server on startup

%package doc
Summary: Documentation for Apache Solr
Group: Documentation
%description doc
This package contains the documentation for Apache Solr

%description doc
Documentation for Apache Solr

%prep
%setup -n hbase-solr-%{hbase_solr_patched_version}

%build
env FULL_VERSION=%{hbase_solr_patched_version} bash %{SOURCE1}

%install
%__rm -rf $RPM_BUILD_ROOT
bash $RPM_SOURCE_DIR/install_hbase_solr.sh \
          --build-dir=${PWD} \
          --prefix=$RPM_BUILD_ROOT \
          --doc-dir=%{doc_solr} \
          --extra-dir=$RPM_SOURCE_DIR

%__install -d -m 0755 $RPM_BUILD_ROOT/%{initd_dir}/
init_file=$RPM_BUILD_ROOT/%{initd_dir}/%{svc_solr}
bash %{SOURCE3} %{SOURCE4} rpm $init_file
chmod 755 $init_file

#%pre
#getent group solr >/dev/null || groupadd -r %{user_solr}
#getent passwd solr > /dev/null || useradd -c "Solr" -s /sbin/nologin -g %{user_solr} -r -d %{state_solr} %{user_solr} 2> /dev/null || :

%post
%{alternatives_cmd} --install %{config_solr} %{solr_name}-conf %{config_solr}.dist 30

%preun
if [ "$1" = 0 ]; then
        %{alternatives_cmd} --remove %{solr_name}-conf %{config_solr}.dist || :
fi

%post indexer 
chkconfig --add %{svc_solr}

%preun indexer 
if [ $1 = 0 ] ; then
        service %{svc_solr} stop > /dev/null 2>&1
        chkconfig --del %{svc_solr}
fi

%postun indexer 
if [ $1 -ge 1 ]; then
        service %{svc_solr} condrestart > /dev/null 2>&1
fi

#######################
#### FILES SECTION ####
#######################
%files 
%defattr(-,root,root,755)
%config(noreplace) %{config_solr}.dist
%{lib_solr}
%{bin_solr}/hbase-indexer
%{bin_solr}/hbase-indexer-sentry
%defattr(-,%{user_solr},%{user_solr},755)
/var/run/hbase-solr
/var/log/hbase-solr
/var/lib/hbase-solr

%files doc
%defattr(-,root,root)
%doc %{doc_solr}

%files indexer 
%attr(0755,root,root) %{initd_dir}/%{svc_solr}
