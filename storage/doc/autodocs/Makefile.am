# Makefile.am for YCP module y2c_storage/doc/autodocs

htmldir = @docdir@/autodocs

html_DATA = index.html $(wildcard *.html)
CLEANFILES = $(html_DATA)

index.html: $(srcdir)/../../src/*.ycp $(srcdir)/../../src/include/*.ycp $(srcdir)/../../src/modules/*.ycp
	@ybindir@/ycpdoc -d. $^
