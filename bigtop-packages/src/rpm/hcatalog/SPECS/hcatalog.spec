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
%define etc_hcatalog /etc/%{name}
%define usr_lib_hcatalog /usr/lib/%{name}
%define bin_hcatalog /usr/bin
%define man_dir %{_mandir}
# After we run "ant package" we'll find the distribution here
%define hcatalog_dist build/hcatalog-%{hcatalog_patched_version}/dist

%if  %{!?suse_version:1}0

%define doc_hcatalog %{_docdir}/%{name}-%{hcatalog_version}

%else

# Only tested on openSUSE 11.4. le'ts update it for previous release when confirmed
%if 0%{suse_version} > 1130
%define suse_check \# Define an empty suse_check for compatibility with older sles
%endif

%define doc_hcatalog %{_docdir}/%{name}

%define __os_install_post \
    %{suse_check} ; \
    /usr/lib/rpm/brp-compress ; \
    %{nil}
%endif


Name: hcatalog
Provides: hcatalog
Version: %{hcatalog_version}
Release: %{hcatalog_release}
Summary: Apache Hcatalog is a data warehouse infrastructure built on top of Hadoop
License: Apache License v2.0
URL: http://incubator.apache.org/hcatalog
Group: Development/Libraries
Buildroot: %{_topdir}/INSTALL/%{name}-%{version}
BuildArch: noarch
Source0: %{name}-%{hcatalog_patched_version}.tar.gz
Source1: do-component-build
Source2: install_hcatalog.sh
Source3: hcatalog.1
Requires: hadoop, hive-metastore, bigtop-utils

%description 
Apache HCatalog is a table and storage management service for data created using Apache Hadoop.
This includes:
    * Providing a shared schema and data type mechanism.
    * Providing a table abstraction so that users need not be concerned with where or how their data is stored.
    * Providing interoperability across data processing tools such as Pig, Map Reduce, Streaming, and Hive.

%prep
%setup -n %{name}-%{hcatalog_patched_version}

%build
env FULL_VERSION=%{hcatalog_patched_version} bash %{SOURCE1}

#########################
#### INSTALL SECTION ####
#########################
%install
%__rm -rf $RPM_BUILD_ROOT
cp $RPM_SOURCE_DIR/hcatalog.1 .
/bin/bash %{SOURCE2} \
  --prefix=$RPM_BUILD_ROOT \
  --build-dir=%{hcatalog_dist} \
  --doc-dir=$RPM_BUILD_ROOT/%{doc_hcatalog}

#######################
#### FILES SECTION ####
#######################
%files
%defattr(-,root,root,755)
%{usr_lib_hcatalog}
%{bin_hcatalog}/hcat
%doc %{doc_hcatalog}
%{man_dir}/man1/hcatalog.1.*
