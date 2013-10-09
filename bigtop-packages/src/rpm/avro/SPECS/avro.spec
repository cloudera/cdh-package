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

%define lib_avro /usr/lib/avro

# disable repacking jars
%define __os_install_post %{nil}

Name: avro-libs
Version: %{avro_version}
Release: %{avro_release}
Summary: A data serialization system
URL: http://avro.apache.org
Group: Development/Libraries
BuildArch: noarch
Buildroot: %(mktemp -ud %{_tmppath}/avro-%{version}-%{release}-XXXXXX)
License: ASL 2.0 
Source0: avro-%{avro_patched_version}.tar.gz
Source1: do-component-build
Source2: install_avro.sh

%description
 Avro provides rich data structures, a compact & fast binary data format, a
 container file to store persistent data, remote procedure calls (RPC), and a
 simple integration with dynamic languages. Code generation is not required to
 read or write data files nor to use or implement RPC protocols. Code
 generation as an optional optimization, only worth implementing for statically
 typed languages.

%package -n avro-tools
Summary: Command-line utilities to work with Avro files
Group: Development/Tools
Requires: %{name} = %{version}-%{release}, bigtop-utils

%description -n avro-tools
 Command-line utilities to work with Avro files

%package -n avro-doc
Summary: JavaDocs for Avro libraries
Group: Development/Tools

%description -n avro-doc
 JavaDocs for Avro libraries

%prep
%setup -n avro-%{avro_patched_version}

%build
env FULL_VERSION=%{avro_patched_version} bash $RPM_SOURCE_DIR/do-component-build

%install
%__rm -rf $RPM_BUILD_ROOT
bash $RPM_SOURCE_DIR/install_avro.sh \
          --build-dir=./ \
          --prefix=$RPM_BUILD_ROOT

#######################
#### FILES SECTION ####
#######################
%files
%defattr(-,root,root,755)
/usr/lib/avro

%files -n avro-tools
/usr/bin/avro-tools

%files -n avro-doc
/usr/share/doc/avro-doc-*
