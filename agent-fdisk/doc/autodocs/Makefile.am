#
# Makefile.am for storage/agent-fdisk/doc/autodocs
#

htmldir = $(docdir)/autodocs

html_DATA = index.html $(wildcard *.html)
CLEANFILES = $(html_DATA)

index.html: $(srcdir)/../../src/*.h
	cd $(srcdir)/../../src && @ybindir@/ydoc agent-fdisk *.h
	mv -f $(srcdir)/../../src/*.html .
