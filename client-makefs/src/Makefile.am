#
# Makefile.am for core/client-makefs/src
#

AM_CXXFLAGS = -DY2LOG=\"client-makefs\"

plugin_LTLIBRARIES = libpy2makefs.la

libpy2makefs_la_SOURCES =				\
	Y2CCMakefs.cc Y2CCMakefs.h			\
	Y2MakefsComponent.cc Y2MakefsComponent.h	\
	Partition.cc Partition.h			\
	Ext2_Partition.cc Ext2_Partition.h		\
	Reiser_Partition.cc Reiser_Partition.h		\
	Fat_Partition.cc Fat_Partition.h		\
	Xfs_Partition.cc Xfs_Partition.h		\
	Jfs_Partition.cc Jfs_Partition.h

libpy2makefs_la_LDFLAGS = -version-info 2:0

INCLUDES =						\
	-I$(srcdir)/../../libycp/src/include		\
	-I$(srcdir)/../../liby2/src/include
