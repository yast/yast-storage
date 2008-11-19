#
# Makefile.am for storage/disk/doc/autodocs
#

htmldir = @docdir@/autodocs

html_DATA = index.html $(wildcard *.html)
CLEANFILES = $(html_DATA)

index.html: $(srcdir)/../../src/*.ycp
	@ybindir@/ycpdoc -d. $(srcdir)/../../src/*.ycp
