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
		StorageControllers.ycp  \
		StorageDevices.ycp

EXTRA_DIST = $(module_DATA) $(ynclude_DATA)

symlinks:
	test -L partitioning || ln -sf ../include partitioning

ycpchook = symlinks

include $(top_srcdir)/Makefile.am.common
