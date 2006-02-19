#
# Makefile.am for storage/controller/src
#
# $Id$
#

yncludedir = @yncludedir@/partitioning

client_DATA =		\
	controller.ycp

if ARCH_S390

desktop_DATA =

else

desktop_DATA = controller.desktop

endif

EXTRA_DIST = $(client_DATA) $(desktop_DATA)
