#
# Makefile.am for storage/agent-fdisk/src
#

AM_CXXFLAGS = -DY2LOG=\"agent-storage\"
INCLUDES = -I$(includedir) -I/usr/include/evms

plugin_LTLIBRARIES = libpy2ag_storage.la
noinst_LTLIBRARIES = liby2ag_storage.la

liby2ag_storage_la_SOURCES =			\
	FdiskAgent.cc	FdiskAgent.h		\
	DiskAcc.cc	DiskAcc.h		\
	FdiskAcc.cc	FdiskAcc.h		\
	PartedAcc.cc	PartedAcc.h		\
	LvmAgent.cc     LvmAgent.h              \
	LvmAccess.cc    LvmAccess.h             \
	MdAgent.cc      MdAgent.h               \
	MdAccess.cc     MdAccess.h              \
	AppUtil.cc	AppUtil.h		\
	AsciiFile.cc	AsciiFile.h		\
	InterCmd.cc	InterCmd.h		\
	SystemCmd.cc	SystemCmd.h		\
	EvmsAgent.cc    EvmsAgent.h             \
	EvmsAccess.cc   EvmsAccess.h            \
	PartInfo.defs.h

libpy2ag_storage_la_SOURCES =				\
	$(liby2ag_storage_la_SOURCES)			\
	Y2CCStorageAgent.cc

libpy2ag_storage_la_LDFLAGS = -version-info 2:0 -levms
libpy2ag_storage_la_LIBADD = @AGENT_LIBADD@

install-data-hook:
	rm -f $(DESTDIR)$(plugindir)/$(plugin_LTLIBRARIES)

# Formerly, the redirection from ag_{fdisk,lvm,md} to ag_storage
# was done in liby2 (sic!)
# Now we make symlinks, which kinda circumvents libtool. Oh well.
install-exec-local: installdirs
	ln -sf libpy2ag_storage.so.2 $(DESTDIR)$(plugindir)/libpy2ag_fdisk.so.2
	ln -sf libpy2ag_storage.so.2 $(DESTDIR)$(plugindir)/libpy2ag_evms.so.2
	ln -sf libpy2ag_storage.so.2 $(DESTDIR)$(plugindir)/libpy2ag_lvm.so.2
	ln -sf libpy2ag_storage.so.2 $(DESTDIR)$(plugindir)/libpy2ag_md.so.2
