Name: spark-netlib
Version: %{spark_netlib_version}
Release: %{spark_netlib_release}
Summary: Netlib shims 

URL: https://github.com/fommil/netlib-java
Group: Development/Libraries
BuildArch: x86_64
Buildroot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
License: GPLv3
#Source0: %{name}-%{spark_netlib_patched_version}.tar.gz
Source0: do-component-build
Source1: install_%{name}.sh
Source2: LICENSE.jniloader
Source3: LICENSE.math-atlas
Source4: LICENSE.netlib-java
Source5: LICENSE.openblas

#I believe this is optional - will wait for opinion of others
%if 0%{?suse_version}
Requires:libgfortran3 
%else
Requires:libgfortran 
%endif

%description
Mission critical components for linear algebra systems, with Fortran performance

%define debug_package %{nil}

%prep
%setup -q -T -c
install -p -m 644 %{SOURCE0} .
install -p -m 644 %{SOURCE1} .
install -p -m 644 %{SOURCE2} .
install -p -m 644 %{SOURCE3} .
install -p -m 644 %{SOURCE4} .
install -p -m 644 %{SOURCE5} .


%build
env FULL_VERSION=%{spark_netlib_patched_version} bash %{SOURCE0}

%install
env FULL_VERSION=%{spark_netlib_patched_version} bash %{SOURCE1} \
    --build-dir=. \
    --prefix=$RPM_BUILD_ROOT

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
/usr/lib/spark-netlib
