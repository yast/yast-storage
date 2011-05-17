#
# Makefile.am for libstorage/src
#

AM_CXXFLAGS =
INCLUDES = -I$(includedir)

.libs: 
	mkdir -p .libs
	ln -sf . .libs/plugin

storage:
	ln -sf . storage

y2storage: storage .libs
	rm -f y2storage
	ln -sf . y2storage

BUILT_SOURCES = y2storage StorageCallbacksBuiltinTable.h StorageCallbacksBuiltinCalls.h

StorageCallbacksBuiltinTable.h : StorageCallbacks.h
	y2tool generateYCPWrappers StorageCallbacks.h StorageCallbacksBuiltinCalls.h StorageCallbacksBuiltinTable.h

StorageCallbacksBuiltinCalls.h : StorageCallbacks.h
	y2tool generateYCPWrappers StorageCallbacks.h StorageCallbacksBuiltinCalls.h StorageCallbacksBuiltinTable.h


lib_LTLIBRARIES = liby2storage.la

liby2storage_la_SOURCES =				\
	StorageInterface.h				\
	Storage.cc		Storage.h		\
	Device.cc		Device.h		\
	Container.cc		Container.h		\
	  Disk.cc		Disk.h			\
	    Dasd.cc		Dasd.h			\
	  PeContainer.cc	PeContainer.h		\
	    LvmVg.cc		LvmVg.h			\
	    DmPartCo.cc		DmPartCo.h		\
	      DmraidCo.cc	DmraidCo.h		\
	      DmmultipathCo.cc	DmmultipathCo.h		\
	    DmCo.cc		DmCo.h			\
	  MdPartCo.cc		MdPartCo.h		\
	  MdCo.cc		MdCo.h			\
	  BtrfsCo.cc		BtrfsCo.h		\
	  TmpfsCo.cc		TmpfsCo.h		\
	  LoopCo.cc		LoopCo.h		\
	  NfsCo.cc		NfsCo.h			\
	Volume.cc		Volume.h		\
	  Partition.cc		Partition.h		\
	  Dm.cc			Dm.h			\
	    LvmLv.cc		LvmLv.h			\
	    DmPart.cc		DmPart.h		\
	      Dmraid.cc		Dmraid.h		\
	      Dmmultipath.cc	Dmmultipath.h		\
	  MdPart.cc		MdPart.h		\
	  Md.cc			Md.h			\
	  Btrfs.cc		Btrfs.h			\
	  Tmpfs.cc		Tmpfs.h			\
	  Loop.cc		Loop.h			\
	  Nfs.cc		Nfs.h			\
	HumanString.cc		HumanString.h		\
	Graph.cc		Graph.h			\
	SystemCmd.cc		SystemCmd.h		\
	OutputProcessor.cc	OutputProcessor.h	\
	Regex.cc		Regex.h			\
	FreeInfo.cc		FreeInfo.h		\
	ArchInfo.cc		ArchInfo.h		\
	AsciiFile.cc		AsciiFile.h		\
	XmlFile.cc		XmlFile.h		\
	SystemInfo.cc		SystemInfo.h		\
	ProcParts.cc		ProcParts.h		\
	Blkid.cc		Blkid.h			\
	Lsscsi.cc		Lsscsi.h		\
	Parted.cc		Parted.h		\
	Dasdview.cc		Dasdview.h		\
	ProcMounts.cc		ProcMounts.h		\
	ProcMdstat.cc		ProcMdstat.h		\
	EtcFstab.cc		EtcFstab.h		\
	EtcMdadm.cc		EtcMdadm.h		\
	Geometry.cc		Geometry.h		\
	AppUtil.cc		AppUtil.h		\
	Enum.cc			Enum.h			\
	Lock.cc			Lock.h			\
	StorageTypes.cc		StorageTypes.h		\
	FilterIterator.h	ListListIterator.h	\
	DerefIterator.h		IterPair.h		\
	Region.cc		Region.h		\
	StorageTmpl.h		StorageDefines.h

liby2storage_la_LDFLAGS = -version-info 2:0
liby2storage_la_LIBADD = -lblocxx -lxml2

plugin_LTLIBRARIES = libpy2StorageCallbacks.la

libpy2StorageCallbacks_la_SOURCES =					\
	Y2StorageCallbacksComponent.cc Y2StorageCallbacksComponent.h	\
	Y2CCStorageCallbacks.cc Y2CCStorageCallbacks.h			\
	StorageCallbacks.h StorageCallbacks.cc

libpy2StorageCallbacks_la_LDFLAGS = -version-info 2:0
libpy2StorageCallbacks_la_LIBADD = -L$(libdir) -ly2 -lycp liby2storage.la

pkgincludedir = $(includedir)/y2storage

pkginclude_HEADERS = StorageInterface.h

CLEANFILES = $(BUILT_SOURCES)
