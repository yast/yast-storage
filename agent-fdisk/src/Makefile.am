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

libpy2ag_storage_la_LDFLAGS = -version-info 2:0

install-data-hook:
	rm -f $(DESTDIR)$(plugindir)/*.la
