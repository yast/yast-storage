#
# Makefile.am for core/client-makefs/doc/autodocs
#

htmldir = $(docdir)/client-makefs/autodocs

html_DATA = \
	Ext2_Partition.html	\
	Y2CCMakefs.html		\
	Y2MakefsComponent.html	\
	heir.html index.html

EXTRA_DIST = $(html_DATA)

CLEANFILES = $(html_DATA)

$(filter-out index.html, $(html_DATA)): index.html
index.html: $(srcdir)/../../src/*.h
	cd $(srcdir)/../../src; @ybindir@/ydoc -p @RPMNAME@ *.h
	mv -f $(srcdir)/../../src/*.html .
