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
%define usr_lib_impala_jdbc /usr/lib/%{name}

%if  %{?suse_version:1}0

# Only tested on openSUSE 11.4. le'ts update it for previous release when confirmed
%if 0%{suse_version} > 1130
%define suse_check \# Define an empty suse_check for compatibility with older sles
%endif

# SLES is more strict anc check all symlinks point to valid path
# But we do point to a hadoop jar which is not there at build time
# (but would be at install time).
# Since our package build system does not handle dependencies,
# these symlink checks are deactivated
%define __os_install_post \
    %{suse_check} ; \
    /usr/lib/rpm/brp-compress ; \
    %{nil}

%endif

Name: impala-jdbc
Version: %{impala_jdbc_version}
Release: %{impala_jdbc_release}
Summary: An Impala-compatible JDBC driver based on Apache Hive 0.12.0
License: ASL 2.0
URL: http://hive.apache.org/
Group: Development/Libraries
Buildroot: %{_topdir}/INSTALL/%{name}-%{version}
BuildArch: noarch
Requires: hadoop
Source0: impala-jdbc-%{impala_jdbc_patched_version}.tar.gz
Source1: do-component-build
Source2: install_impala-jdbc.sh
Source3: packaging_functions.sh

%description
An Impala-compatible JDBC driver based on Apache Hive 0.12.0

%prep
%setup -n impala-jdbc-%{impala_jdbc_patched_version}

%build
env FULL_VERSION=%{impala_jdbc_patched_version} bash %{SOURCE1}

#########################
#### INSTALL SECTION ####
#########################
%install
/bin/bash %{SOURCE2} \
  --prefix=$RPM_BUILD_ROOT \
  --build-dir=. \
  --extra-dir=$RPM_SOURCE_DIR

%files
%defattr(-,root,root,755)
%{usr_lib_impala_jdbc}

