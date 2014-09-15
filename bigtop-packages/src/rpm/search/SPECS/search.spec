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
%define lib_dir   /usr/lib/%{name}

%if  %{?suse_version:1}0

# Only tested on openSUSE 11.4. le'ts update it for previous release when confirmed
%if 0%{suse_version} > 1130
%define suse_check \# Define an empty suse_check for compatibility with older sles
%endif

# SLES is more strict and check all symlinks point to valid path
# But we do point to a hadoop jar which is not there at build time
# (but would be at install time).
# Since our package build system does not handle dependencies,
# these symlink checks are deactivated
%define __os_install_post \
    %{suse_check} ; \
    /usr/lib/rpm/brp-compress ; \
    %{nil}

%define doc_dir %{_docdir}/%{name}
%define alternatives_cmd update-alternatives
%global initd_dir %{_sysconfdir}/rc.d

%else

%define doc_dir %{_docdir}/%{name}-%{version}
%define alternatives_cmd alternatives
%global initd_dir %{_sysconfdir}/rc.d/init.d

%endif



Name: search
Version: %{search_version}
Release: %{search_release}
Summary: Cloudera Search Project 
URL: http://www.cloudera.com/
Group: Development/Libraries
Buildroot: %{_topdir}/INSTALL/%{name}-%{version}
BuildArch: noarch
License: ASL 2.0
Source0: search-%{search_patched_version}.tar.gz
Source1: do-component-build
Source2: install_solr_sink.sh
Source3: packaging_functions.sh
Requires: bigtop-utils >= 0.7
Requires: avro-libs, parquet, sentry >= 1.3.0+cdh5.1.3, solr >= 4.4.0+cdh5.1.3, kite >= 0.10.0+cdh5.1.3, hbase, hadoop-hdfs, hadoop, zookeeper, avro-libs

%description
Cloudera Search Project

%prep
%setup -n %{name}-%{search_patched_version}

%build
env FULL_VERSION=%{search_patched_version} bash -x %{SOURCE1}

%install
%__rm -rf $RPM_BUILD_ROOT
bash %{SOURCE2} \
          --build-dir=$PWD \
          --doc-dir=%{doc_dir} \
          --prefix=$RPM_BUILD_ROOT \
          --extra-dir=$RPM_SOURCE_DIR
%files
%defattr(-,root,root,755)
%{lib_dir}
%{doc_dir}

%package -n solr-mapreduce
Summary: Solr mapreduce indexer
Group: Development/Libraries
Requires: hadoop-client, bigtop-utils >= 0.7

%description -n solr-mapreduce
Solr mapreduce indexer

%files -n solr-mapreduce
%defattr(644,root,root,755)
/usr/lib/solr/contrib
