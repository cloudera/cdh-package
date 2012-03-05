#
# Copyright (c) 2010-2011, Cloudera Inc
#

##### HUE METAPACKAGE ######
Name:    hue
Version: %{hue_version}
Release: %{hue_release}
Group: Applications/Engineering
Summary: The hue metapackage
License: ASL 2.0
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Source0: %{name}-%{hue_patched_version}.tar.gz
Source1: %{name}.init
Source2: %{name}.init.suse
Source3: do-component-build
URL: http://github.com/cloudera/hue
Vendor: Cloudera, Inc.
Requires: hadoop
Requires: %{name}-plugins = %{version}-%{release}
Requires: %{name}-common = %{version}-%{release}
Requires: %{name}-filebrowser = %{version}-%{release}
Requires: %{name}-about = %{version}-%{release}
Requires: %{name}-help = %{version}-%{release}
Requires: %{name}-jobsub = %{version}-%{release}
Requires: %{name}-jobbrowser = %{version}-%{release}
Requires: %{name}-beeswax = %{version}-%{release}
Requires: %{name}-proxy = %{version}-%{release}
Requires: %{name}-shell = %{version}-%{release}
# hue-user is a virtual package
Requires: %{name}-user

%description -n hue
Will install the entire set of hue and its plugins/applications

%files -n hue

%description
The hue metapackage, including hue-common and all hue applications.

##############################


################ RPM CUSTOMIZATION ##############################

# Disable automatic Provides generation - otherwise we will claim to provide all of the
# .so modules that we install inside our private lib directory, which will falsely
# satisfy dependencies for other RPMs on the target system.
AutoProv: no
AutoReqProv: no
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

# Init.d directory has different locations dependeing on the OS
%if  %{!?suse_version:1}0
%global initd_dir %{_sysconfdir}/rc.d/init.d
%else
%global initd_dir %{_sysconfdir}/rc.d
%endif


############### DESKTOP SPECIFIC CONFIGURATION ##################

# customization of install spots
%define hue_dir /usr/share/hue
%define hadoop_home /usr/lib/hadoop
%define hadoop_lib %{hadoop_home}/lib
%define username hue

%define apps_dir %{hue_dir}/apps
%define about_app_dir %{hue_dir}/apps/about
%define beeswax_app_dir %{hue_dir}/apps/beeswax
%define filebrowser_app_dir %{hue_dir}/apps/filebrowser
%define help_app_dir %{hue_dir}/apps/help
%define jobbrowser_app_dir %{hue_dir}/apps/jobbrowser
%define jobsub_app_dir %{hue_dir}/apps/jobsub
%define proxy_app_dir %{hue_dir}/apps/proxy
%define shell_app_dir %{hue_dir}/apps/shell
%define useradmin_app_dir %{hue_dir}/apps/useradmin

# Path to the HADOOP_HOME to build against - these
# are not substituted into the build products anywhere!
%if ! %{?build_hadoop_home:1} %{!?build_hadoop_home:0}
  %define build_hadoop_home %{hadoop_home}
%endif

# Post macro for apps
%define app_post_macro() \
%post -n %{name}-%1 \
DO="su --shell=/bin/bash -l %{username} -c" \
export ROOT=%{hue_dir} \
export DESKTOP_LOGLEVEL=WARN \
export DESKTOP_LOG_DIR=/var/log/hue \
chown -R %{username}:%{username} %{hue_dir}/apps/%1 \
if [ "$1" != 1 ] ; then \
  echo %{hue_dir}/apps/%1 >> %{hue_dir}/.re_register \
fi \
$DO "%{hue_dir}/build/env/bin/python %{hue_dir}/tools/app_reg/app_reg.py --install %{apps_dir}/%1"

# Preun macro for apps
%define app_preun_macro() \
%preun -n %{name}-%1 \
if [ "$1" = 0 ] ; then \
  DO="su --shell=/bin/bash -l %{username} -c" \
  ENV_PYTHON="%{hue_dir}/build/env/bin/python" \
  export ROOT=%{hue_dir} \
  export DESKTOP_LOGLEVEL=WARN \
  export DESKTOP_LOG_DIR=/var/log/hue \
  if [ -e $ENV_PYTHON ] ; then \
    $DO "$ENV_PYTHON %{hue_dir}/tools/app_reg/app_reg.py --remove %1" ||: \
  fi \
  find %{apps_dir}/%1 -name \*.egg-info -type f -print0 | xargs -0 /bin/rm -fR   \
fi \
find %{apps_dir}/%1 -iname \*.py[co] -type f -print0 | xargs -0 /bin/rm -f  



%description
Hue is a browser-based desktop interface for interacting with Hadoop.
It supports a file browser, job tracker interface, cluster health monitor, and more.


%clean
%__rm -rf $RPM_BUILD_ROOT


%prep
%setup -n %{name}-%{hue_patched_version}

########################################
# Build
########################################
%build
HADOOP_HOME=%{build_hadoop_home} \
  make apps

########################################
# Install
########################################
%install

HADOOP_HOME=%{build_hadoop_home} \
  PREFIX=$RPM_BUILD_ROOT/usr/share/ \
  make install

%if  %{?suse_version:1}0
orig_init_file=$RPM_SOURCE_DIR/%{name}.init.suse
%else
orig_init_file=$RPM_SOURCE_DIR/%{name}.init
%endif

# TODO maybe dont need this line anymore:
%__install -d -m 0755 $RPM_BUILD_ROOT/%{initd_dir}
cp $orig_init_file $RPM_BUILD_ROOT/%{initd_dir}/hue


# Install conf
mkdir -p $RPM_BUILD_ROOT/etc/
mv $RPM_BUILD_ROOT/usr/share/hue/desktop/conf $RPM_BUILD_ROOT/etc/hue
ln -s /etc/hue $RPM_BUILD_ROOT/usr/share/hue/desktop/conf

# Plugins
#ROOT=$(pwd) HADOOP_HOME=%{build_hadoop_home} \
#  make -C desktop/libs/hadoop bdist
mkdir -p %{buildroot}%{hue_dir}/desktop/libs/hadoop/java-lib \
  %{buildroot}%{hadoop_lib}
cp desktop/libs/hadoop/java-lib/*plugin* %{buildroot}%{hue_dir}/desktop/libs/hadoop/java-lib/
cp desktop/libs/hadoop/java-lib/*plugin* %{buildroot}%{hadoop_lib}/


# Fix broken symlinks by removing $RPM_BUILD_ROOT references
for sm in $RPM_BUILD_ROOT/usr/share/hue/build/env/lib64; do

  if [ -h ${sm} ]
  then
    SM_ORIG_DEST_FILE=`ls -l "${sm}" | sed -e 's/.*-> //' `
    SM_DEST_FILE=`echo $SM_ORIG_DEST_FILE | sed -e "s|${RPM_BUILD_ROOT}||"`

    rm ${sm}
    ln -s ${SM_DEST_FILE} ${sm}
  fi

done

# Fix broken python scripts
HUE_BIN_SCRIPTS=$RPM_BUILD_ROOT/usr/share/hue/build/env/bin/*
HUE_EGG_SCRIPTS=$RPM_BUILD_ROOT/build/env/lib*/python*/site-packages/*/EGG-INFO/scripts/*
for file in $HUE_BIN_SCRIPTS $HUE_EGG_SCRIPTS;
do
  if [ -f ${file} ]
  then
    sed -i -e "s|${RPM_BUILD_ROOT}||" ${file}
  fi
done

#Installing plug-ins configuration files
mkdir -p $RPM_BUILD_ROOT/etc/hue

# Beeswax
mv $RPM_BUILD_ROOT/%{hue_dir}/apps/beeswax/conf/hue-beeswax.ini $RPM_BUILD_ROOT/etc/hue
rmdir $RPM_BUILD_ROOT/%{hue_dir}/apps/beeswax/conf

# Shell
SHELL_DIR=$RPM_BUILD_ROOT/%{hue_dir}/apps/shell
mv $SHELL_DIR/conf/hue-shell.ini $RPM_BUILD_ROOT/etc/hue
rmdir $SHELL_DIR/conf

# Make binary scripts executables
for file in $RPM_BUILD_ROOT/%{hue_dir}/build/env/bin/ ;
do
  chmod 755 $file
done

# Remove bogus files
BUILD_LOG=`find $RPM_BUILD_ROOT/ -iname "build_log.txt"`
for ALL_BORKED in $BUILD_LOG;
do
  rm -fv $ALL_BORKED
done

ALL_PTH_BORKED=`find $RPM_BUILD_ROOT/ -iname "*.pth"`
ALL_REG_BORKED=`find $RPM_BUILD_ROOT/ -iname "app.reg"`
ALL_PYTHON_BORKED=`find $RPM_BUILD_ROOT/%{hue_dir}/build/env/lib/python*/site-packages/ -type f -iname "*"`
for file in $ALL_PTH_BORKED $ALL_REG_BORKED $ALL_PYTHON_BORKED;
do
  sed -i -e "s|${RPM_BUILD_ROOT}||" ${file}
done

#### PLUGINS ######

%package -n %{name}-common
Summary: A browser-based desktop interface for Hadoop
BuildRequires: python-devel, python-setuptools, gcc, gcc-c++
BuildRequires: libxml2-devel, libxslt-devel, zlib-devel
BuildRequires: cyrus-sasl-devel
BuildRequires: openssl
#BuildRequires: hadoop, bigtop-utils
Group: Applications/Engineering
Requires: cyrus-sasl-gssapi, libxml2, libxslt, zlib, python, sqlite
Conflicts: cloudera-desktop
Provides: %{name}-common = %{version}, config(%{name}-common) = %{version}

%if  %{?suse_version:1}0
BuildRequires: sqlite3-devel, openldap2-devel, libmysqlclient-devel, libopenssl-devel
# Required for init scripts
Requires: insserv, python-xml
%else
BuildRequires: /sbin/runuser, sqlite-devel, openldap-devel, mysql-devel, openssl-devel
# Required for init scripts
Requires: redhat-lsb
%endif

# Disable automatic Provides generation - otherwise we will claim to provide all of the
# .so modules that we install inside our private lib directory, which will falsely
# satisfy dependencies for other RPMs on the target system.
AutoReqProv: no

%description -n %{name}-common
Hue is a browser-based desktop interface for interacting with Hadoop.
It supports a file browser, job tracker interface, cluster health monitor, and more.

########################################
# Preinstall
########################################
%pre -n %{name}-common -p /bin/bash
getent group %{username} 2>/dev/null >/dev/null || /usr/sbin/groupadd -r %{username}
getent passwd %{username} 2>&1 > /dev/null || /usr/sbin/useradd -c "Hue" -s /sbin/nologin -g %{username} -r -d %{hue_dir} %{username} 2> /dev/null || :

# Stop any running Hue
if [ "$1" != 1 ]; then \
  echo "Stopping any running Hue..."
  /sbin/service hue stop || :
fi

# If there is an old DB in place, make a backup.
if [ -e %{hue_dir}/desktop/desktop.db ]; then
  echo "Backing up previous version of Hue database..."
  cp -a %{hue_dir}/desktop/desktop.db %{hue_dir}/desktop/desktop.db.rpmsave.$(date +'%Y%m%d.%H%M%S')
fi

########################################
# Postinstall
########################################
%post -n %{name}-common -p /bin/bash

cd %{hue_dir}
DO="su --shell=/bin/bash -l %{username} -c"
DESKTOP_LOG_DIR=/var/log/hue

mkdir -p $DESKTOP_LOG_DIR
chown %{username}:%{username} $DESKTOP_LOG_DIR

# Set permissions
chown %{username}:%{username} %{hue_dir}/*
chown %{username}:%{username} %{hue_dir}/apps
chown -R %{username}:%{username} %{hue_dir}/ext
chown -R %{username}:%{username} %{hue_dir}/tools
chown -R %{username}:%{username} %{hue_dir}/desktop

# Force regeneration of the virtual-env
rm -f %{hue_dir}/build/env/stamp

# Delete all pyc files since they contain the wrong path ()
find %{hue_dir} -iname \*.py[co]  -exec rm -f {} \;

# Install everything into the virtual environment
# TODO: Should this be in /var/log/hue?
$DO "DESKTOP_LOG_DIR=$DESKTOP_LOG_DIR DESKTOP_LOGLEVEL=WARN make desktop" >& %{hue_dir}/build_log.txt

# Upgrading database...
$DO "DESKTOP_LOG_DIR=$DESKTOP_LOG_DIR DESKTOP_LOGLEVEL=WARN build/env/bin/hue syncdb --noinput"

# Delete all pyc files since they contain the wrong path ()
find %{hue_dir} -iname \*.py[co]  -exec rm -f {} \;

# Install and start init scripts
chkconfig --add hue

########################################
# Pre-uninstall
########################################
%preun -n %{name}-common -p /bin/bash
/sbin/service hue stop > /dev/null ; \
if [ "$1" = 0 ]; then \
  chkconfig --del hue ; \
fi

########################################
# Post-uninstall
########################################
%postun -n %{name}-common -p /bin/bash

if [ -d %{hue_dir} ]; then
  find %{hue_dir} -name \*.py[co] -exec rm -f {} \;
fi

if [ $1 -eq 0 ]; then
  # TODO this seems awfully aggressive
  # NOTE  Despite dependency, hue-common could get removed before the apps are.
  #       We should remove app.reg because apps won't have a chance to
  #       unregister themselves.
  rm -Rf %{hue_dir}/desktop %{hue_dir}/build %{hue_dir}/pids %{hue_dir}/app.reg
fi



%files -n %{name}-common
%defattr(-,%{username},%{username})
%attr(0755,root,root) %config(noreplace) /etc/hue/
%dir %{hue_dir}
%{hue_dir}/desktop
%{hue_dir}/ext
%{hue_dir}/LICENSE.txt
%{hue_dir}/Makefile
%{hue_dir}/Makefile.buildvars
%{hue_dir}/Makefile.sdk
%{hue_dir}/Makefile.vars
%{hue_dir}/Makefile.vars.priv
%{hue_dir}/README
%{hue_dir}/tools
%{hue_dir}/VERSION
%{hue_dir}/VERSION_DATA
%attr(0755,%{username},%{username}) %{hue_dir}/build/env/bin/*
%{hue_dir}/build/env/include/
%{hue_dir}/build/env/lib*/
%{hue_dir}/build/env/stamp
## We exclude app.reg to prevent it getting overwritten,
##  postinstall should generate this see: CDH-3820
%exclude %{hue_dir}/app.reg
%{hue_dir}/apps/Makefile
%dir %{hue_dir}/apps
%attr(0755,root,root) %{initd_dir}/hue



%exclude %{hadoop_lib}

# Exclude hue database
%exclude %{hue_dir}/desktop/desktop.db

%exclude %{about_app_dir}
%exclude %{beeswax_app_dir}
%exclude %{filebrowser_app_dir}
%exclude %{help_app_dir}
%exclude %{jobbrowser_app_dir}
%exclude %{jobsub_app_dir}
%exclude %{proxy_app_dir}
%exclude %{useradmin_app_dir}

%exclude %{shell_app_dir}
%exclude /etc/hue/hue-shell.ini
%exclude /etc/hue/hue-beeswax.ini


############################################################
# No-arch packages - plugins and conf
############################################################


#### PLUGINS ######
%package -n %{name}-plugins
Summary: Hadoop plugins for Hue
Requires: hadoop, bigtop-utils
Group: Applications/Engineering
Conflicts: cloudera-desktop-plugins
%description -n %{name}-plugins
Plugins for Hue

This package should be installed on each node in the Hadoop cluster.

%files -n %{name}-plugins
%{hadoop_lib}/



#### HUE-ABOUT PLUGIN ######
%package -n %{name}-about
Summary: Show version and configuration information about Hue
Group: Applications/Engineering
Requires: %{name}-common = %{version}-%{release}
Requires: make


%description -n %{name}-about
Displays the current version and configuration information about your Hue installation.

%app_post_macro about 
%app_preun_macro about 

%files -n %{name}-about
%defattr(-, %{username}, %{username})
%{about_app_dir}




#### HUE-BEESWAX PLUGIN ######
%package -n %{name}-beeswax
Summary: A UI for Hive on Hue
Group: Applications/Engineering
Requires: make
Requires: %{name}-common = %{version}-%{release}
Requires: %{name}-jobbrowser = %{version}-%{release}
Requires: %{name}-filebrowser = %{version}-%{release}
Requires: %{name}-jobsub = %{version}-%{release}
Requires: %{name}-help = %{version}-%{release}
Requires: hive

%description -n %{name}-beeswax
Beeswax is a web interface for Hive.

It allows users to construct and run queries on Hive, manage tables,
and import and export data.

%app_post_macro beeswax
%app_preun_macro beeswax

%files -n %{name}-beeswax
%defattr(-, %{username}, %{username})
%{beeswax_app_dir}
%config /etc/hue/hue-beeswax.ini
%attr(0755,root,root) /etc/hue/hue-beeswax.ini


#### HUE-FILEBROWSER PLUGIN ######

%package -n %{name}-filebrowser
Summary: A UI for the Hadoop Distributed File System (HDFS)
Group: Applications/Engineering
Requires: make
Requires: %{name}-common = %{version}-%{release}
Requires: %{name}-help = %{version}-%{release}

%description -n %{name}-filebrowser
Filebrowser is a graphical web interface that lets you browse and interact with the Hadoop Distributed File System (HDFS).

%app_post_macro filebrowser
%app_preun_macro filebrowser

%files -n %{name}-filebrowser
%defattr(-, %{username}, %{username})
%{filebrowser_app_dir}


#### HUE-HELP PLUGIN ######
%package -n %{name}-help
Summary: Display help documentation for various Hue apps
Group: Applications/Engineering
Requires: %{name}-common = %{version}-%{release}
Requires: make

%description -n %{name}-help
Displays help documentation for various Hue apps.

%app_post_macro help
%app_preun_macro help

%files -n %{name}-help
%defattr(-, %{username}, %{username})
%{help_app_dir}


#### HUE-JOBBROWSER PLUGIN ######

%package -n %{name}-jobbrowser
Summary: A UI for viewing Hadoop map-reduce jobs
Group: Applications/Engineering
Requires: make
Requires: %{name}-common = %{version}-%{release}
Requires: %{name}-filebrowser = %{version}-%{release}
Requires: %{name}-help = %{version}-%{release}

%description -n %{name}-jobbrowser
Jobbrowser is a web interface for viewing Hadoop map-reduce jobs running on your cluster.

%app_post_macro jobbrowser
%app_preun_macro jobbrowser

%files -n %{name}-jobbrowser
%defattr(-, %{username}, %{username})
%{jobbrowser_app_dir}


#### HUE-JOBSUB PLUGIN ######

%package -n %{name}-jobsub
Summary: A UI for designing and submitting map-reduce jobs to Hadoop
Group: Applications/Engineering
Requires: make
Requires: %{name}-common = %{version}-%{release}
Requires: %{name}-jobbrowser = %{version}-%{release}
Requires: %{name}-help = %{version}-%{release}

%description -n %{name}-jobsub
Jobsub is a web interface for designing and submitting map-reduce jobs to Hadoop.

%app_post_macro jobsub
%app_preun_macro jobsub

%files -n %{name}-jobsub
%defattr(-, %{username}, %{username})
%{jobsub_app_dir}


#### HUE-PROXY PLUGIN ######

%package -n %{name}-proxy
Summary: Reverse proxy for the Hue server
Group: Applications/Engineering
Requires: make
Requires: %{name}-common = %{version}-%{release}

%description -n %{name}-proxy
Proxies HTTP requests through the Hue server. This is intended to be used for "built-in" UIs.

%app_post_macro proxy
%app_preun_macro proxy

%files -n %{name}-proxy
%defattr(-, %{username}, %{username})
%{proxy_app_dir}


#### HUE-USERADMIN PLUGIN ######
%package -n %{name}-useradmin
Summary: Create/delete users, update user information
Group: Applications/Engineering
Provides: %{name}-user
Requires: make
Requires: %{name}-common = %{version}-%{release}
Requires: %{name}-filebrowser = %{version}-%{release}
Requires: %{name}-about = %{version}-%{release}
Requires: %{name}-help = %{version}-%{release}

%description -n %{name}-useradmin
Create/delete Hue users, and update user information (name, email, superuser status, etc.)

%app_post_macro useradmin
%app_preun_macro useradmin

%files -n %{name}-useradmin
%defattr(-, %{username}, %{username})
%{useradmin_app_dir}

############################################################
# Arch packages - plugins and conf
############################################################

#### HUE-PROXY PLUGIN ######
%package -n %{name}-shell
Summary: A shell for console based Hadoop applications
Group: Applications/Engineering
Requires: make
Requires: %{name}-common = %{version}-%{release}
Requires: %{name}-help = %{version}-%{release}

# Disable automatic Provides generation - otherwise we will claim to provide all of the
# .so modules that we install inside our private lib directory, which will falsely
# satisfy dependencies for other RPMs on the target system.
AutoReqProv: no

%description -n %{name}-shell
The Shell application lets the user connect to various backend shells (e.g. Pig, HBase, Flume).

%post -n %{name}-shell
DO="su --shell=/bin/bash -l %{username} -c"
export ROOT=%{hue_dir}
export DESKTOP_LOGLEVEL=WARN
export DESKTOP_LOG_DIR=/var/log/hue
chown -R %{username}:%{username} %{hue_dir}/apps/shell

$DO "%{hue_dir}/build/env/bin/python %{hue_dir}/tools/app_reg/app_reg.py --install %{shell_app_dir}"

chown root:hue %{shell_app_dir}/src/shell/build/setuid
chmod 4750 %{shell_app_dir}/src/shell/build/setuid


%app_preun_macro shell

%files -n %{name}-shell
%defattr(-, %{username}, %{username})
%{shell_app_dir}
%attr(0755,root,root) %config(noreplace) /etc/hue/hue-shell.ini
%attr(4750,root,hue) %{shell_app_dir}/src/shell/build/setuid

