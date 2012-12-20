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
%define etc_flume /etc/flume-ng/conf
%define lib_flume /usr/lib/flume-ng

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

%define doc_flume %{_docdir}/flume-ng
%define alternatives_cmd update-alternatives
%global initd_dir %{_sysconfdir}/rc.d

%else

%define doc_flume %{_docdir}/flume-ng-%{flume_ng_version}
%define alternatives_cmd alternatives
%global initd_dir %{_sysconfdir}/rc.d/init.d

%endif



Name: flume-ng-solr
Version: %{flume_ng_solr_version}
Release: %{flume_ng_solr_release}
Summary: Flume NG Solr Sink 
URL: http://flume.apache.org/
Group: Development/Libraries
Buildroot: %{_topdir}/INSTALL/%{name}-%{version}
BuildArch: noarch
License: APL2
Source0: %{name}-%{flume_ng_solr_patched_version}.tar.gz
Source1: do-component-build
Source2: install_solr_sink.sh
Requires: flume-ng

%description 
Flume NG Solr Sink

%prep
%setup -n %{name}-%{flume_ng_solr_patched_version}

%build
env FULL_VERSION=%{flume_ng_solr_patched_version} bash -x %{SOURCE1}

%install
%__rm -rf $RPM_BUILD_ROOT
sh %{SOURCE2} \
          --build-dir=$PWD \
          --prefix=$RPM_BUILD_ROOT

%files 
%defattr(644,root,root,755)
%config(noreplace) %{etc_flume}.dist/*
%{lib_flume}/lib

# FIXME: once solr-mr and core indexer go upstream we need to rationalize this
%package -n solr-mapreduce
Summary: Solr mapreduce indexer
Group: Development/Libraries
Requires: hadoop-client, bigtop-utils

%description -n solr-mapreduce
Solr mapreduce indexer

%files -n solr-mapreduce
%defattr(644,root,root,755)
/usr/lib/solr/contrib/mr/*.jar
