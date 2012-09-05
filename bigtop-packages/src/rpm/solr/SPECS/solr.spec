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

%define solr_name solr
%define lib_solr /usr/lib/%{solr_name}
%define etc_solr /etc/%{solr_name}
%define config_solr %{etc_solr}/conf
%define log_solr /var/log/%{solr_name}
%define bin_solr /usr/bin
%define man_dir /usr/share/man

%if  %{?suse_version:1}0
%define doc_solr %{_docdir}/solr-doc
%define alternatives_cmd update-alternatives
%else
%define doc_solr %{_docdir}/solr-doc-%{solr_version}
%define alternatives_cmd alternatives
%endif

# disable repacking jars
%define __os_install_post %{nil}

Name: solr
Version: %{solr_version}
Release: %{solr_release}
Summary: Apache Solr is the popular, blazing fast open source enterprise search platform
URL: http://lucene.apache.org/solr
Group: Development/Libraries
BuildArch: noarch
Buildroot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
License: ASL 2.0 
Source0: solr-%{solr_patched_version}.tar.gz
Source1: do-component-build 
Source2: install_%{name}.sh
Requires: bigtop-utils


%description 
Solr is the popular, blazing fast open source enterprise search platform from
the Apache Lucene project. Its major features include powerful full-text
search, hit highlighting, faceted search, dynamic clustering, database
integration, rich document (e.g., Word, PDF) handling, and geospatial search.
Solr is highly scalable, providing distributed search and index replication,
and it powers the search and navigation features of many of the world's
largest internet sites.

Solr is written in Java and runs as a standalone full-text search server within
a servlet container such as Tomcat. Solr uses the Lucene Java search library at
its core for full-text indexing and search, and has REST-like HTTP/XML and JSON
APIs that make it easy to use from virtually any programming language. Solr's
powerful external configuration allows it to be tailored to almost any type of
application without Java coding, and it has an extensive plugin architecture
when more advanced customization is required.

%package doc
Summary: Documentation for Apache Solr
Group: Documentation
%description doc
This package contains the documentation for Apache Solr


%prep
%setup -n solr-%{solr_patched_version}

%build
env FULL_VERSION=%{solr_patched_version} bash %{SOURCE1}

%install
%__rm -rf $RPM_BUILD_ROOT
sh $RPM_SOURCE_DIR/install_solr.sh \
          --build-dir=build/solr-%{solr_patched_version} \
          --prefix=$RPM_BUILD_ROOT \
          --doc-dir=%{doc_solr} 

%post
%{alternatives_cmd} --install %{config_solr} %{solr_name}-conf %{config_solr}.dist 30

%preun
if [ "$1" = 0 ]; then
        %{alternatives_cmd} --remove %{solr_name}-conf %{config_solr}.dist || :
fi

#######################
#### FILES SECTION ####
#######################
%files 
%defattr(-,root,root,755)
%config(noreplace) %{config_solr}.dist
%{lib_solr}
%{bin_solr}/solr
/var

%files doc
%defattr(-,root,root)
%doc %{doc_solr}
