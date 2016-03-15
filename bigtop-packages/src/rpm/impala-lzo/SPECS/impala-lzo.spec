
# This is needed to generate debuginfo packages.
# This macro defaults to 1 in CentOS6.6 and RHEL7 which causes /usr/lib/rpm/find-debuginfo.sh
# to error out:
# *** ERROR: No build ID note found in /data/jenkins/workspace/generic-package-rhel64-6-0-impala
#     /buildroot/usr/lib/impala/lib/libimpalalzo.so
%undefine _missing_build_ids_terminate_build

Name: impala-lzo
Version: %{impala_lzo_version}
Release: %{impala_lzo_release}
Summary: GPL Compression Libraries for Impala.
Group: Development/Libraries
License: GPLv2
URL: https://github.com/cloudera/Impala-lzo
Source0: impala-lzo-%{impala_lzo_patched_version}.tar.gz
Source1: do-component-build 
Source2: install_impala-lzo.sh
Source3: gpl-2.0.txt
BuildArch: i386 amd64 x86_64
BuildRoot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXX)
BuildRequires: gcc, gcc-c++, lzo-devel
Requires: lzo

%description
Impala-LZO is an addon to provide LZO compression support in Impala.

%prep
%setup -n impala-lzo-%{impala_lzo_patched_version}

%build
env FULL_VERSION=%{impala_lzo_patched_version} NATIVE_BUILD=true bash $RPM_SOURCE_DIR/do-component-build

%install
bash $RPM_SOURCE_DIR/install_impala-lzo.sh \
    --build-dir=. \
    --prefix=$RPM_BUILD_ROOT
cp %{SOURCE3} $RPM_BUILD_ROOT/usr/lib/impala/lib/COPYING.impala-lzo

%post
# Necessary for natives
/sbin/ldconfig

%postun
# Necessary for natives
/sbin/ldconfig

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
/usr/lib/impala
