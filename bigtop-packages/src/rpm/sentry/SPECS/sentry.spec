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

# disable repacking jars
%define __os_install_post %{nil}

Name: sentry
Version: %{sentry_version}
Release: %{sentry_release}
Summary: Authorization component
URL: https://github.com/cloudera/access
Group: Development/Libraries
BuildArch: noarch
Buildroot: %(mktemp -ud %{_tmppath}/%{datafu_name}-%{version}-%{release}-XXXXXX)
License: ASL 2.0
Source0: sentry-%{sentry_patched_version}.tar.gz
Source1: do-component-build
Source2: install_sentry.sh
Requires: hadoop-hdfs, hive

%description
Cloudera authorization component and the corresponding Hive plugin

%prep
%setup -n sentry-%{sentry_patched_version}

%build
env FULL_VERSION=%{sentry_patched_version} bash $RPM_SOURCE_DIR/do-component-build

%install
%__rm -rf $RPM_BUILD_ROOT
sh %{SOURCE2} \
          --build-dir=$PWD \
          --prefix=$RPM_BUILD_ROOT

%files
%defattr(-,root,root,755)
/usr/lib/hive/sentry
/usr/lib/hive/lib
