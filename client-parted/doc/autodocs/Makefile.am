#
# Makefile.am for storage/client-parted/doc/autodocs
#

htmldir = $(docdir)/client-parted/autodocs

html_DATA = index.html $(wildcard *.html)

CLEANFILES = $(html_DATA)

index.html: $(srcdir)/../../src/*.h
	cd $(srcdir)/../../src; @ybindir@/ydoc -p client-parted *.h
	mv -f $(srcdir)/../../src/*.html .
