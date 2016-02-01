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


Name: keytrustee-server
Version: %{keytrustee_server_version}
Release: %{keytrustee_server_release}
Summary: Server component of the KeyTrustee trusted deposit and retrieval suite
URL: http://www.cloudera.com
Group: Development/Libraries
BuildArch: x86_64
Buildroot: %{_topdir}/INSTALL/%{name}-%{version}
BuildRequires: python-setuptools python-unittest2
License: Proprietary
Source0: keytrustee-server-%{keytrustee_server_patched_version}.tar.gz
Source1: do-component-build
Source2: install_keytrustee-server.sh
Source3: packaging_functions.sh
Requires: bigtop-utils >= 0.7
%{!?python_sitelib: %global python_sitelib %(%{__python} -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())")}


# SuSE/openSuSE
%if 0%{?suse_version}
Requires: apache2, apache2-mod_wsgi, gnutls, postfix, postgresql93-server, postgresql93, python-setuptools, python-crypto, python-psycopg2, pyOpenSSL, python-Flask, python-Flask-SQLAlchemy, python-psutil, python-keytrustee = %{version} rsync
%endif

# RHEL == 6
%if 0%{?rhel} == 6
Requires: python-sqlalchemy0.8, python-jinja2-26
%endif

# RHEL == 7
%if 0%{?rhel} == 7
Requires: python-sqlalchemy
%endif

# RHEL 6 & 7
%if 0%{?rhel} >= 6
Requires: cyrus-sasl-plain, gnutls-utils, python-crypto, openssh-clients, postfix, postgresql93-server, postgresql93, python-psycopg2 >= 2.5.0, pyOpenSSL, py-bcrypt, python-cherrypy, python-paste, python-setuptools, python-flask, python-psutil, python-keytrustee = %{version} rsync
%endif

%description  
KeyTrustee trusted deposit and retrieval suite. A KeyTrustee client
compatible SW is used on physical or virtual server or desktop systems
to register, get, and put secret information to an KeyTrustee server.


%package -n python-keytrustee
Summary: Code shared between the client and server.
Requires: pytz, python-argparse, python-pycurl, python-requests

%description -n python-keytrustee
KeyTrustee server libraries

%define debug_package %{nil}

%prep
%setup -n %{name}-%{keytrustee_server_patched_version}

%clean
rm -rf $RPM_BUILD_ROOT

%build
env FULL_VERSION=%{keytrustee_server_patched_version} bash %{SOURCE1}

%install
%__rm -rf $RPM_BUILD_ROOT
env FULL_VERSION=%{keytrustee_server_patched_version} bash %{SOURCE2} \
          --build-dir=$RPM_SOURCE_DIR \
          --prefix=$RPM_BUILD_ROOT \
          --extra-dir=$RPM_SOURCE_DIR

# Install init scripts

# Install security limits

%post %{nil}

%files -n python-keytrustee
%defattr(-,root,root)
%{python_sitelib}/keytrustee/*.py
%{python_sitelib}/keytrustee/*.py[co]
%{python_sitelib}/keytrustee/backports/*.py
%{python_sitelib}/keytrustee/backports/*.py[co]
%{python_sitelib}/keytrustee*.egg-info

%files 
%defattr(-,root,root)
%{python_sitelib}/keytrustee/server/*
%{python_sitelib}/keytrustee/hsm/*
/usr/bin/ktadmin
/usr/share/keytrustee-server/*
/usr/lib/keytrustee-server/*
/usr/bin/keytrustee-orgtool
/usr/bin/keytrustee-server
/usr/share/man/man1/*
/usr/share/man/man8/*
/usr/share/keytrustee/LICENSE

%if 0%{?rhel} == 6
/etc/init.d/keytrusteed
/etc/init.d/keytrustee-db
%endif

%if 0%{?rhel} == 7
/usr/lib/systemd/system/keytrusteed.service
/usr/lib/systemd/system/keytrustee-db.service
%endif

%pre
groupadd -r keytrustee || :
useradd -m -r -g keytrustee \
    -d /var/lib/keytrustee \
    -s /bin/bash \
    -k /dev/null \
    -c "Account used to manage keytrustee" \
    keytrustee || :
install -d /var/lib/keytrustee -o keytrustee -g keytrustee -m 0700
exit 0

%preun 
if rmdir /var/lib/keytrustee &> /dev/null; then
    userdel keytrustee || :
    groupdel keytrustee || :
fi
exit 0
