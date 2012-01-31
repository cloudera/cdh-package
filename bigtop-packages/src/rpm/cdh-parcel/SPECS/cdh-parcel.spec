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

Name: cdh-parcel-%{cdh_parcel_base_version}
Version: %{cdh_parcel_version}
Release: %{cdh_parcel_release}
Summary: All the server side CDH java bits in one relocatable package

Group:		Applications/Engineering
License:	APL2
URL:		http://cloudera.com
Source0:	do-component-build

BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

BuildArch: noarch
Prefix: /opt
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
    /usr/lib/rpm/brp-python-bytecompile ; \
    %{nil}
%else
%define __os_install_post \
    %{suse_check} ; \
    /usr/lib/rpm/brp-compress ; \
    %{nil}
%endif


%package -n cdh-parcel-client-%{cdh_parcel_base_version}
Summary: All the client side CDH java bits in one relocatable package
Group: System/Daemons
Requires: %{name}
Prefix: /opt
AutoReq: no
AutoProv: no

%description -n cdh-parcel-client-%{cdh_parcel_base_version}
This package delivers all the client side java bits for CDH and can be
installed side-by-side with different versions of the same package.


%prep
%setup -q -T -c

%build
bash -x %{SOURCE0}

%install
mkdir -p $RPM_BUILD_ROOT/opt
mv $PWD/build/usr $RPM_BUILD_ROOT/opt/%{name}
chmod 555 $RPM_BUILD_ROOT/opt/%{name}/lib/hadoop/bin/container-executor
rm -rf $RPM_BUILD_ROOT/opt/%{name}/lib/debug $RPM_BUILD_ROOT/opt/%{name}/src

%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(-,root,root,-)
%exclude /opt/%{name}/*/pig
%exclude /opt/%{name}/*/hive
%exclude /opt/%{name}/*/sqoop
%exclude /opt/%{name}/*/mahout
/opt
%attr(6050,root,yarn) /opt/%{name}/lib/hadoop/bin/container-executor

%files -n cdh-parcel-client-%{cdh_parcel_base_version}
%defattr(-,root,root,-)
/opt/%{name}/*/pig
/opt/%{name}/*/hive
/opt/%{name}/*/sqoop
/opt/%{name}/*/mahout

%changelog


