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
%define var_lib_kms /var/lib/kms-keytrustee


Name: keytrustee-keyprovider
Version: %{keytrustee_keyprovider_version}
Release: %{keytrustee_keyprovider_release}
Summary: Key Trustee Key Provider package
URL: http://www.cloudera.com
Group: Development/Libraries
BuildArch: x86_64
Buildroot: %{_topdir}/INSTALL/%{name}-%{version}
License: Proprietary
Source0: keytrustee-keyprovider-%{keytrustee_keyprovider_patched_version}.tar.gz
Source1: do-component-build
Source2: install_keytrustee-keyprovider.sh
Source3: packaging_functions.sh
Requires: bigtop-utils >= 0.7,hadoop-kms


%description 
Key Trustee Key Provider package

%define debug_package %{nil}

%prep
%setup -n %{name}-%{keytrustee_keyprovider_patched_version}

%clean
rm -rf $RPM_BUILD_ROOT

%build
env FULL_VERSION=%{keytrustee_keyprovider_patched_version} bash %{SOURCE1}

%install
%__rm -rf $RPM_BUILD_ROOT
env FULL_VERSION=%{keytrustee_keyprovider_patched_version} bash %{SOURCE2} \
          --build-dir=$RPM_SOURCE_DIR \
          --prefix=$RPM_BUILD_ROOT \
          --extra-dir=$RPM_SOURCE_DIR

# Install init scripts

# Install security limits

%pre %{nil}

%preun %{nil}

%post %{nil}

%files
/usr/share/keytrustee-keyprovider/cloudera
/usr/share/keytrustee-keyprovider/lib
/usr/share/keytrustee-keyprovider/README.md
%attr(-,kms,kms) %var_lib_kms 
