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

%define lib_parquet /usr/lib/parquet
%define hadoop_home /usr/lib/hadoop

# disable repacking jars
%define __os_install_post %{nil}

Name: parquet-format
Version: %{parquet_format_version}
Release: %{parquet_format_release}
Summary: Format definitions for Parquet
URL: http://parquet.io
Group: Development/Libraries
BuildArch: noarch
Buildroot: %(mktemp -ud %{_tmppath}/parquet-format-%{version}-%{release}-XXXXXX)
License: ASL 2.0
Source0: parquet-format-%{parquet_format_patched_version}.tar.gz
Source1: do-component-build 
Source2: install_parquet-format.sh
Requires: hadoop
Requires: parquet >= 1.2.3

%description
Format definitions for Parquet

%prep
%setup -n parquet-format-%{parquet_format_patched_version}

%build
bash $RPM_SOURCE_DIR/do-component-build

%install
%__rm -rf $RPM_BUILD_ROOT
sh $RPM_SOURCE_DIR/install_parquet-format.sh \
          --build-dir=./ \
          --prefix=$RPM_BUILD_ROOT

#######################
#### FILES SECTION ####
#######################
%files 
%defattr(-,root,root,755)
%{lib_parquet}/parquet-format
%{lib_parquet}/*.jar
%{lib_parquet}/lib/*.jar
%{hadoop_home}/*.jar
