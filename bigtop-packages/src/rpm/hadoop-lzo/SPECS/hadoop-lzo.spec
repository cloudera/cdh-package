%define hadoop_home /usr/lib/hadoop
%define _use_internal_dependency_generator 0

Name: hadoop-lzo
Version: %{hadoop_lzo_version}
Release: %{hadoop_lzo_release}
Summary: GPL Compression Libraries for Hadoop. Hadoop-LZO is a project to bring splittable LZO compression to Hadoop
URL: https://github.com/toddlipcon/hadoop-lzo
Group: Development/Libraries
BuildArch: i386 amd64 x86_64
Buildroot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
License: GPLv3
Source0: %{name}-%{hadoop_lzo_patched_version}.tar.gz
Source1: do-component-build
Source2: install_%{name}.sh
Source3: gpl-3.0.txt
BuildRequires: gcc, gcc-c++, lzo-devel, jpackage-utils
Requires: jpackage-utils, lzo, rtld(GNU_HASH)

%description
Hadoop-LZO is a project to bring splittable LZO compression to Hadoop. LZO is an ideal compression format for Hadoop due to its combination of speed and compression size. However, LZO files are not natively splittable, meaning the parallelism that is the core of Hadoop is gone. This project re-enables that parallelism with LZO compressed files, and also comes with standard utilities (input/output streams, etc) for working with LZO files.

%package mr1
Summary: Hadoop-LZO libraries for clusters using the hadoop-0.20-mapreduce packages
Group: Development/Libraries
Requires: hadoop-lzo

%description mr1
Hadoop-LZO libraries for clusters using the hadoop-0.20-mapreduce packages

%prep
%setup -n %{name}-%{hadoop_lzo_patched_version}

# Requires: exclude libjvm.so since it generally isn't installed
# on the system library path, and we don't want to have to install
# with --nodeps
# RHEL doesn't have nice macros. Oh well. Do it old school.
%define our_req_script %{name}-find-req.sh
cat <<__EOF__ > %{our_req_script}
!/bin/bash
%{__find_requires} | grep -v libjvm
__EOF__
%define __find_requires %{_builddir}/%{name}-%{hadoop_lzo_patched_version}/%{our_req_script}
chmod +x %{__find_requires}

%build
env FULL_VERSION=%{hadoop_lzo_patched_version} bash %{SOURCE1}

%install
bash %{SOURCE2} \
    --build-dir=. \
    --prefix=$RPM_BUILD_ROOT
cp %{SOURCE3} $RPM_BUILD_ROOT/usr/lib/hadoop/lib/COPYING.hadoop-lzo

%post
# Necessary for natives
/sbin/ldconfig

%postun
# Necessary for natives
/sbin/ldconfig

%clean
rm -rf $RPM_BUILD_ROOT

#######################
#### FILES SECTION ####
#######################
%files
%defattr(-,root,root,-)
#%doc CHANGES.txt COPYING README.md
%{hadoop_home}/lib

%files mr1
%{hadoop_home}-0.20-mapreduce/lib
