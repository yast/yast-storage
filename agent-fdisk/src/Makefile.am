#
# Makefile.am for ag_fdisk/src
#

AM_CXXFLAGS = -DY2LOG=\"agent-fdisk\"

plugin_LTLIBRARIES = libpy2ag_fdisk.la libpy2ag_lvm.la libpy2ag_md.la
noinst_LTLIBRARIES = liby2ag_fdisk.la liby2ag_lvm.la liby2ag_md.la

liby2ag_fdisk_la_SOURCES =			\
	FdiskAgent.cc	FdiskAgent.h		\
	DiskAcc.cc	DiskAcc.h		\
	FdiskAcc.cc	FdiskAcc.h		\
	PartedAcc.cc	PartedAcc.h		\
	AppUtil.cc	AppUtil.h		\
	AsciiFile.cc	AsciiFile.h		\
	InterCmd.cc	InterCmd.h		\
	SystemCmd.cc	SystemCmd.h		\
	PartInfo.defs.h

libpy2ag_fdisk_la_SOURCES =				\
	$(liby2ag_fdisk_la_SOURCES)			\
	Y2CCFdiskAgent.cc Y2CCFdiskAgent.h		\
	Y2FdiskAgentComponent.cc Y2FdiskAgentComponent.h

libpy2ag_fdisk_la_LDFLAGS = -version-info 2:0

liby2ag_lvm_la_SOURCES =			\
	LvmAccess.cc	LvmAccess.h		\
	MdAccess.cc	MdAccess.h		\
	LvmAgent.cc	LvmAgent.h		\
	DiskAcc.cc	DiskAcc.h		\
	FdiskAcc.cc	FdiskAcc.h		\
	PartedAcc.cc	PartedAcc.h		\
	AppUtil.cc	AppUtil.h		\
	AsciiFile.cc	AsciiFile.h		\
	SystemCmd.cc	SystemCmd.h		\
	PartInfo.defs.h

libpy2ag_lvm_la_SOURCES =				\
	$(liby2ag_lvm_la_SOURCES)			\
	Y2CCLvmAgent.cc Y2CCLvmAgent.h		        \
	Y2LvmAgentComponent.cc Y2LvmAgentComponent.h

libpy2ag_lvm_la_LDFLAGS = -version-info 2:0

liby2ag_md_la_SOURCES =			\
	MdAccess.cc	MdAccess.h	\
	MdAgent.cc	MdAgent.h       \
	DiskAcc.cc	DiskAcc.h		\
	FdiskAcc.cc	FdiskAcc.h		\
	PartedAcc.cc	PartedAcc.h		\
	AppUtil.cc	AppUtil.h		\
	AsciiFile.cc	AsciiFile.h		\
	SystemCmd.cc	SystemCmd.h		\
	PartInfo.defs.h

libpy2ag_md_la_SOURCES =				\
	$(liby2ag_md_la_SOURCES)			\
	Y2CCMdAgent.cc Y2CCMdAgent.h		        \
	Y2MdAgentComponent.cc Y2MdAgentComponent.h

libpy2ag_md_la_LDFLAGS = -version-info 2:0

INCLUDES = -I$(includedir)

