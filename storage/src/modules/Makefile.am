#
# Files being accessed using "import" should be installed to
#

YCPCFLAGS = -I .

yncludedir = @yncludedir@/storage

ynclude_DATA =		\
	routines.ycp

module_DATA =				\
		Partitions.ycp		\
		FileSystems.ycp		\
		Storage.ycp		\
		StorageClients.ycp      \
		StorageControllers.ycp  \
		StorageDevices.ycp

EXTRA_DIST = $(module_DATA) $(ynclude_DATA)

include:
	mkdir include && ln -sf ../../include include/partitioning

ycpchook = include

include $(top_srcdir)/Makefile.am.common
