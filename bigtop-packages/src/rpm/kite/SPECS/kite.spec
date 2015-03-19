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

%define kite_name kite 
%define lib_kite /usr/lib/kite

%if  %{?suse_version:1}0
%define doc_kite %{_docdir}/kite-doc
%else
%define doc_kite %{_docdir}/kite-doc-%{kite_version}
%endif

# disable repacking jars
%define __os_install_post %{nil}

Name: kite
Version: %{kite_version}
Release: %{kite_release}
Summary: Kite Software Development Kit.
URL: http://kitesdk.org
Group: Development/Libraries
BuildArch: noarch
Buildroot: %(mktemp -ud %{_tmppath}/%{kite_name}-%{version}-%{release}-XXXXXX)
License: ASL 2.0
Source0: %{kite_name}-%{kite_patched_version}.tar.gz
Source1: do-component-build 
Source2: install_%{kite_name}.sh
Source3: packaging_functions.sh
Requires: hadoop-client, bigtop-utils >= 0.7, solr >= 4.4.0+cdh5.1.5
Requires: avro-libs, parquet, sentry >= 1.3.0+cdh5.1.5, hadoop, zookeeper

%description 
The Kite Software Development Kit, is a set of libraries, tools, examples, and
documentation focused on making it easier to build systems on top of the
Hadoop ecosystem.

%prep
%setup -n %{kite_name}-%{kite_patched_version}

%build
env FULL_VERSION=%{kite_patched_version} bash $RPM_SOURCE_DIR/do-component-build

%install
%__rm -rf $RPM_BUILD_ROOT
bash $RPM_SOURCE_DIR/install_kite.sh \
          --build-dir=build/kite-%{kite_patched_version} \
          --prefix=$RPM_BUILD_ROOT \
          --extra-dir=$RPM_SOURCE_DIR

#######################
#### FILES SECTION ####
#######################
%files 
%defattr(-,root,root,755)
%{lib_kite}
%{lib_kite}/cloudera/cdh_version.properties

