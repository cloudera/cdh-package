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


##### HUE METAPACKAGE ######
Name:    hue-search
Version: %{hue_search_version}
Release: %{hue_search_release}
Group: Applications/Engineering
Summary: A UI for Search on Hue
License: ASL 2.0
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id} -u -n)
Source0: %{name}-%{hue_search_patched_version}.tar.gz
Source3: do-component-build
Source4: install_hue.sh
URL: http://github.com/cloudera/hue
Vendor: Cloudera, Inc.
Requires: hue-common, hue-user, hue-about, hue-help
Requires(pre): hue-common
Requires(preun): hue-common
AutoReqProv: no
AutoProv: no

############### DESKTOP SPECIFIC CONFIGURATION ##################

# customization of install spots
%define hue_dir /usr/share/hue
%define hadoop_home /usr/lib/hadoop
%define hadoop_lib %{hadoop_home}/lib
%define username hue

%define apps_dir %{hue_dir}/apps
%define about_app_dir %{hue_dir}/apps/about
%define beeswax_app_dir %{hue_dir}/apps/beeswax
%define oozie_app_dir %{hue_dir}/apps/oozie
%define pig_app_dir %{hue_dir}/apps/pig
%define search_app_dir %{hue_dir}/apps/search
%define metastore_app_dir %{hue_dir}/apps/metastore
%define filebrowser_app_dir %{hue_dir}/apps/filebrowser
%define help_app_dir %{hue_dir}/apps/help
%define jobbrowser_app_dir %{hue_dir}/apps/jobbrowser
%define jobsub_app_dir %{hue_dir}/apps/jobsub
%define proxy_app_dir %{hue_dir}/apps/proxy
%define shell_app_dir %{hue_dir}/apps/shell
%define useradmin_app_dir %{hue_dir}/apps/useradmin
%define impala_app_dir %{hue_dir}/apps/impala

# Path to the HADOOP_HOME to build against - these
# are not substituted into the build products anywhere!
%if ! %{?build_hadoop_home:1} %{!?build_hadoop_home:0}
  %define build_hadoop_home %{hadoop_home}
%endif

# Post macro for apps
%define app_post_macro() \
%post \
export ROOT=%{hue_dir} \
export DESKTOP_LOGLEVEL=WARN \
export DESKTOP_LOG_DIR=/var/log/hue \
if [ "$1" != 1 ] ; then \
  echo %{hue_dir}/apps/%1 >> %{hue_dir}/.re_register \
fi \
%{hue_dir}/build/env/bin/python %{hue_dir}/tools/app_reg/app_reg.py --install %{apps_dir}/%1 \
(cd %{hue_dir} ; /bin/bash ./tools/relocatable.sh) \
chown -R hue:hue /var/log/hue \
chown hue:hue %{hue_dir}/desktop %{hue_dir}/desktop/desktop.db

# Preun macro for apps
%define app_preun_macro() \
%preun \
if [ "$1" = 0 ] ; then \
  export ROOT=%{hue_dir} \
  export DESKTOP_LOGLEVEL=WARN \
  export DESKTOP_LOG_DIR=/var/log/hue \
  if [[ -e $ENV_PYTHON && -f %{hue_dir}/tools/app_reg/app_reg.py ]] ; then \
    %{hue_dir}/build/env/bin/python %{hue_dir}/tools/app_reg/app_reg.py --remove %1 ||: \
  fi \
  find %{apps_dir}/%1 -name \*.egg-info -type f -print0 | xargs -0 /bin/rm -fR   \
fi \
find %{apps_dir}/%1 -iname \*.py[co] -type f -print0 | xargs -0 /bin/rm -f \
chown -Rf hue:hue /var/log/hue \
chown -f hue:hue %{hue_dir}/desktop %{hue_dir}/desktop/desktop.db ||:

%description
A web interface for Search.

It allows users to interact with Solr.

%app_post_macro search
%app_preun_macro search

%files
%{search_app_dir}


################ RPM CUSTOMIZATION ##############################
# Disable automatic Provides generation - otherwise we will claim to provide all of the
# .so modules that we install inside our private lib directory, which will falsely
# satisfy dependencies for other RPMs on the target system.
%define _use_internal_dependency_generator 0

# Disable post hooks (brp-repack-jars, etc) that just take forever and sometimes cause issues
%define __os_install_post \
    %{!?__debug_package:/usr/lib/rpm/brp-strip %{__strip}} \
%{nil}
%define __jar_repack %{nil}
%define __prelink_undo_cmd %{nil}

# Disable debuginfo package, since we never need to gdb
# our own .sos anyway
%define debug_package %{nil}

# there are some file by-products we don't want to actually package
%define _unpackaged_files_terminate_build 0

%clean
%__rm -rf $RPM_BUILD_ROOT

%prep
%setup -n %{name}-%{hue_search_patched_version}

########################################
# Build
########################################
%build
bash -x %{SOURCE3}  

########################################
# Install
########################################
%install
bash -x %{SOURCE4} --prefix=$RPM_BUILD_ROOT --build-dir=${PWD}
