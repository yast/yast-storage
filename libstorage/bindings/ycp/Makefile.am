#
# Makefile.am for libstorage/bindings/ycp
#

PLUGLIB_MODULE = LibStorage
PLUGLIB_LIBRARY = /usr/lib/libstorage.so
PLUGLIB_DEPEND =					\
	/usr/include/storage/StorageInterface.h		\
	/usr/include/storage/HumanString.h		\
	/usr/include/storage/Graph.h

include $(top_srcdir)/pluglib-bindings.ami

EXTRA_DIST = LibStorage.i example.ycp
