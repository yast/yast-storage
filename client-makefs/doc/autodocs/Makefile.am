#
# Makefile.am for storage/client-makefs/doc/autodocs
#

htmldir = $(docdir)/client-makefs/autodocs

html_DATA = index.html $(wildcard *.html)

CLEANFILES = $(html_DATA)

index.html: $(srcdir)/../../src/*.h
	cd $(srcdir)/../../src; @ybindir@/ydoc -p client-makefs *.h
	mv -f $(srcdir)/../../src/*.html .
