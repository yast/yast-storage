#
# Makefile.am for core/client-parted/doc/autodocs
#

htmldir = $(docdir)/client-parted/autodocs

html_DATA = \
	WIN_Partition.html	\
	Y2CCParted.html		\
	Y2PartedComponent.html	\
	heir.html index.html

EXTRA_DIST = $(html_DATA)

CLEANFILES = $(html_DATA)

$(filter-out index.html, $(html_DATA)): index.html
index.html: $(srcdir)/../../src/*.h
	cd $(srcdir)/../../src; @ybindir@/ydoc -p @RPMNAME@ *.h
	mv -f $(srcdir)/../../src/*.html .
