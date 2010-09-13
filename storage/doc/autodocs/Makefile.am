#
# Makefile.am for storage/storage/doc/autodocs
#

htmldir = @docdir@/autodocs

html_DATA = index.html $(filter-out index.html, $(wildcard *.html))
CLEANFILES = $(html_DATA)

index.html: $(srcdir)/../../src/*.ycp $(srcdir)/../../src/include/*.ycp $(srcdir)/../../src/modules/*.ycp
	@ybindir@/ycpdoc -d. $^
