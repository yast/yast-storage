#
# Makefile.am for storage/client-parted/testsuite
#

AUTOMAKE_OPTIONS = dejagnu

INCLUDES =

noinst_PROGRAMS = y2parted
y2parted_SOURCES = y2parted.cc

y2parted_LDADD = -ly2 -lycp
y2parted_LDFLAGS = -L$(libdir)				\
	-Xlinker --whole-archive			\
	$(plugindir)/libpy2stdio.la			\
	$(srcdir)/../src/libpy2parted.la		\
	-Xlinker --no-whole-archive

clean-local:
	rm -f tmp.err.* tmp.out.* *.log *.sum site.exp
