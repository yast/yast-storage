#
# spec file for package yast2-storage
#
# Copyright (c) 2015 SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           yast2-storage
Version:        3.1.75
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

Group:		System/YaST
License:	GPL-2.0

BuildRequires:	docbook-xsl-stylesheets
BuildRequires:	doxygen
BuildRequires:	gcc-c++ libtool
BuildRequires:	libstorage-devel >= 2.25.23
BuildRequires:	libstorage-ruby >= 2.25.23
BuildRequires:	libxslt
BuildRequires:	perl-XML-Writer
BuildRequires:	rubygem(rspec)
BuildRequires:	rubygem(ruby-dbus)
BuildRequires:	sgml-skel
BuildRequires:	update-desktop-files
BuildRequires:	yast2 >= 3.1.22
BuildRequires:	yast2-core-devel >= 2.23.1
BuildRequires:	yast2-devtools >= 3.1.10
BuildRequires:	yast2-ruby-bindings >= 3.1.7
BuildRequires:	yast2-testsuite >= 2.19.0
Requires:	libstorage-ruby >= 2.25.23
Requires:	libstorage6 >= 2.25.23
Requires:	rubygem(%{rb_default_ruby_abi}:ruby-dbus)
Requires:	yast2 >= 3.1.22
Requires:	yast2-core >= 2.18.3
Requires:	yast2-libyui >= 2.18.7
%ifarch s390 s390x
Requires:	yast2-s390
%endif
PreReq:		%fillup_prereq
Provides:	y2a_fdsk yast2-config-disk
Obsoletes:	y2a_fdsk yast2-config-disk
Provides:	yast2-agent-fdisk yast2-agent-fdisk-devel
Obsoletes:	yast2-agent-fdisk yast2-agent-fdisk-devel
Provides:	yast2-trans-inst-partitioning
Obsoletes:	yast2-trans-inst-partitioning
Provides:	y2t_inst-partitioning
Obsoletes:	y2t_inst-partitioning
Requires:	yast2-ruby-bindings >= 3.1.7

Summary:	YaST2 - Storage Configuration
Url:		http://github.com/yast/yast-storage/

%description
This package contains the files for YaST2 that handle access to disk
devices during installation and on an installed system.

%prep
%setup -n %{name}-%{version}

%build
%yast_build

%install
%yast_install

rm -f $RPM_BUILD_ROOT/%{yast_plugindir}/libpy2StorageCallbacks.la
rm -f $RPM_BUILD_ROOT/%{yast_plugindir}/libpy2StorageCallbacks.so


%post
%{fillup_only -an storage}

%files
%defattr(-,root,root)

# storage
%dir %{yast_yncludedir}/partitioning
%{yast_yncludedir}/partitioning/*.rb
%{yast_clientdir}/inst_custom_part.rb
%{yast_clientdir}/inst_resize_ui.rb
%{yast_clientdir}/inst_resize_dialog.rb
%{yast_clientdir}/inst_disk.rb
%{yast_clientdir}/inst_target_part.rb
%{yast_clientdir}/inst_disk_proposal.rb
%{yast_clientdir}/inst_target_selection.rb
%{yast_clientdir}/inst_prepdisk.rb
%{yast_clientdir}/storage_finish.rb
%{yast_clientdir}/partitions_proposal.rb
%{yast_clientdir}/storage.rb
%{yast_clientdir}/disk.rb
%{yast_clientdir}/disk_worker.rb
%{yast_clientdir}/multipath-simple.rb
%{yast_moduledir}/*
%dir %{yast_libdir}/storage
%{yast_libdir}/storage/*.rb
/var/adm/fillup-templates/sysconfig.storage-yast2-storage

%dir %{yast_ydatadir}
%{yast_ydatadir}/*.ycp

%doc %dir %{yast_docdir}
%doc %{yast_docdir}/README*
%doc %{yast_docdir}/COPY*

# agents-scr
%{yast_scrconfdir}/*.scr

# libstorage ycp callbacks
%{yast_plugindir}/libpy2StorageCallbacks.so.*

# disk
%dir %{yast_desktopdir}
%{yast_desktopdir}/disk.desktop

# scripts
%{yast_ybindir}/check.boot

%package devel
Requires:	libstdc++-devel
Requires:	libstorage-devel = %(echo `rpm -q --queryformat '%{VERSION}' libstorage-devel`)
Requires:	yast2-storage = %version

Summary:        YaST2 - Storage Library Headers and Documentation
Group:          Development/Libraries/YaST

%description devel
This package contains the files for YaST2 that are needed if one wants
to develop a program using yast2-storage.

%files devel
%defattr(-,root,root)
%doc %{yast_docdir}/autodocs
%doc %{yast_docdir}/config.xml.description
