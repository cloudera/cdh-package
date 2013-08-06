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

%define cdk_name cdk 
%define lib_cdk /usr/lib/cdk

%if  %{?suse_version:1}0
%define doc_cdk %{_docdir}/cdk-doc
%else
%define doc_cdk %{_docdir}/cdk-doc-%{cdk_version}
%endif

# disable repacking jars
%define __os_install_post %{nil}

Name: cdk
Version: %{cdk_version}
Release: %{cdk_release}
Summary: Cloudera Development Kit.
URL: https://github.com/cloudera/cdk
Group: Development/Libraries
BuildArch: noarch
Buildroot: %(mktemp -ud %{_tmppath}/%{cdk_name}-%{version}-%{release}-XXXXXX)
License: ASL 2.0 
Source0: %{cdk_name}-%{cdk_patched_version}.tar.gz
Source1: do-component-build 
Source2: install_%{cdk_name}.sh
Requires: hadoop-client, bigtop-utils >= 0.6

%description 
The Cloudera Development Kit, or CDK for short, is a set of libraries, 
tools, examples, and documentation focused on making it easier to build 
systems on top of the Hadoop ecosystem.

%prep
%setup -n %{cdk_name}-%{cdk_patched_version}

%build
env FULL_VERSION=%{cdk_patched_version} bash $RPM_SOURCE_DIR/do-component-build

%install
%__rm -rf $RPM_BUILD_ROOT
sh $RPM_SOURCE_DIR/install_cdk.sh \
          --build-dir=dist \
          --prefix=$RPM_BUILD_ROOT

#######################
#### FILES SECTION ####
#######################
%files 
%defattr(-,root,root,755)
%{lib_cdk}
%{lib_cdk}/cloudera/cdh_version.properties


