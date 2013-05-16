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
%define man_dir %{_mandir}

%if  %{?suse_version:1}0
%define bin_jsvc /usr/lib/bigtop-utils
%define doc_jsvc %{_docdir}/%{name}
%define compat_jsvc %{nil}
%else
%define bin_jsvc /usr/lib/bigtop-utils
%define doc_jsvc %{_docdir}/%{name}-%{bigtop_jsvc_version}
%define compat_jsvc %{_libexecdir}/bigtop-utils
%endif

Name: bigtop-jsvc
Version: %{bigtop_jsvc_version}
Release: %{bigtop_jsvc_release}
Summary: Application to launch java daemon
URL: http://commons.apache.org/daemon/
Group: Development/Libraries
Buildroot: %{_topdir}/INSTALL/%{name}-%{version}
License: ASL 2.0
Source0: bigtop-jsvc-%{bigtop_jsvc_patched_version}.tar.gz
Source1: do-component-build
Source2: install_jsvc.sh
BuildRequires: ant, autoconf, automake, gcc

%description 
jsvc executes classfile that implements a Daemon interface.

%prep
%setup -n bigtop-jsvc-%{bigtop_jsvc_patched_version}

%clean
rm -rf $RPM_BUILD_ROOT

%build
env FULL_VERSION=%{bigtop_jsvc_patched_version} bash %{SOURCE1}

%install
%__rm -rf $RPM_BUILD_ROOT
sh %{SOURCE2} \
          --build-dir=build/bigtop-jsvc-%{bigtop_jsvc_patched_version}  \
          --bin-dir=%{bin_jsvc} \
          --doc-dir=%{doc_jsvc} \
          --man-dir=%{man_dir}  \
          --prefix=$RPM_BUILD_ROOT

if [ -n "%{compat_jsvc}" ] ; then 
  %__install -d -m 0755 $RPM_BUILD_ROOT/%{compat_jsvc}
  %__cp $RPM_BUILD_ROOT/%{bin_jsvc}/*  $RPM_BUILD_ROOT/%{compat_jsvc}
fi


%files
%defattr(-,root,root)
%{bin_jsvc}
%{compat_jsvc}
%doc %{doc_jsvc}


%changelog

