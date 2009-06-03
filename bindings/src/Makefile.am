#
# Makefile.am for storage/bindings/src
#

INCLUDES = -I$(includedir)

.libs/plugin:
	mkdir .libs
	ln -sf . .libs/plugin

BUILT_SOURCES = .libs/plugin StorageCallbacksBuiltinTable.h StorageCallbacksBuiltinCalls.h

StorageCallbacksBuiltinTable.h : StorageCallbacks.h
	y2tool generateYCPWrappers StorageCallbacks.h StorageCallbacksBuiltinCalls.h StorageCallbacksBuiltinTable.h

StorageCallbacksBuiltinCalls.h : StorageCallbacks.h
	y2tool generateYCPWrappers StorageCallbacks.h StorageCallbacksBuiltinCalls.h StorageCallbacksBuiltinTable.h


plugin_LTLIBRARIES = libpy2StorageCallbacks.la

libpy2StorageCallbacks_la_SOURCES =					\
	Y2StorageCallbacksComponent.cc Y2StorageCallbacksComponent.h	\
	Y2CCStorageCallbacks.cc Y2CCStorageCallbacks.h			\
	StorageCallbacks.cc StorageCallbacks.h

libpy2StorageCallbacks_la_LDFLAGS = -version-info 2:0
libpy2StorageCallbacks_la_LIBADD = -L$(libdir) -ly2 -lycp -lstorage

CLEANFILES = $(BUILT_SOURCES)
