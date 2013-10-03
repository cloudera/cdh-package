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

%define distro_less_version_release %(echo %{version}-%{release} | sed -e 's/\.[^\.]*$//')
%define parcel_default_root /opt/cloudera/parcels/CDH-%{distro_less_version_release}

Name: cdh-parcel-%{cdh_parcel_base_version}
Version: %{cdh_parcel_version}
Release: %{cdh_parcel_release}
Summary: All the server side CDH java bits in one relocatable package

Group:		Applications/Engineering
License:	APL2
URL:		http://cloudera.com
Source0:        cdh-parcel-%{cdh_parcel_patched_version}.tar.gz
Source1:	do-component-build
Source2:        hadoop-fuse-dfs.patch

BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

BuildArch: noarch
Prefix: %{parcel_default_root}
AutoReq: no
AutoProv: no

%description
This package delivers all the server side java bits for CDH and can be
installed side-by-side with different versions of the same package. It is
useful in cases where you would want to do rolling upgrades of your cluster
and you have some other mechanism for managing orchestration.



%define debug_package %{nil}
%if  %{!?suse_version:1}0
%define __os_install_post \
    /usr/lib/rpm/redhat/brp-compress ; \
    /usr/lib/rpm/redhat/brp-strip-static-archive %{__strip} ; \
    /usr/lib/rpm/redhat/brp-strip-comment-note %{__strip} %{__objdump} ; \
    %{nil}
%else
%define __os_install_post \
    %{suse_check} ; \
    /usr/lib/rpm/brp-compress ; \
    %{nil}
%endif


%prep
%setup -c

%build
PKG_FORMAT=rpm FULL_VERSION=%{cdh_parcel_version}-%{cdh_parcel_release} CDH_PARCEL_CUSTOM_VERSION=%{version}-%{release} \
CDH_CUSTOMER_PATCH=%{cdh_customer_patch} CDH_PARCEL_BASE_VERSION=%{cdh_parcel_version} bash -x %{SOURCE1}

%install
patch -p0 < %{SOURCE2}

# the following stops rpm from complaining
chmod 555 $PWD/build/usr/lib/hadoop-yarn/bin/container-executor
chmod 555 $PWD/build/usr/lib/hadoop-0.20-mapreduce/sbin/*/task-controller
chmod 555 $PWD/build/usr/share/hue/apps/shell/src/shell/build/setuid

DEST=$RPM_BUILD_ROOT/%{parcel_default_root}
mkdir -p $DEST
mv $PWD/build/usr/lib* $PWD/build/usr/share $PWD/build/usr/bin $PWD/build/meta $PWD/build/etc $DEST

%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(-,root,root,-)
%attr(0755,root,root)   %{parcel_default_root}
%attr(4754,root,yarn)   %{parcel_default_root}/lib/hadoop-yarn/bin/container-executor
%attr(4754,root,mapred) %{parcel_default_root}/lib/hadoop-0.20-mapreduce/sbin/*/task-controller
%attr(4750,root,hue)    %{parcel_default_root}/share/hue/apps/shell/src/shell/build/setuid
%attr(0755,hue,hue)     %{parcel_default_root}/share/hue/desktop
%attr(0644,hue,hue)     %{parcel_default_root}/share/hue/desktop/desktop.db

%changelog


