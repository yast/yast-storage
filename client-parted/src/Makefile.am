#
# Makefile.am for core/client-parted/src
#

AM_CXXFLAGS = -DY2LOG=\"client-parted\"

plugin_LTLIBRARIES = libpy2parted.la

libpy2parted_la_SOURCES =				\
	Y2CCParted.cc Y2CCParted.h			\
	Y2PartedComponent.cc Y2PartedComponent.h	\
	WIN_Partition.cc WIN_Partition.h

libpy2parted_la_LDFLAGS = -version-info 2:0

INCLUDES =						\
	-I$(srcdir)/../../libycp/src/include		\
	-I$(srcdir)/../../liby2/src/include
