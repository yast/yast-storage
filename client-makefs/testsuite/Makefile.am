#
# Makefile.am for core/client-makefs/testsuite
#

AUTOMAKE_OPTIONS = dejagnu

INCLUDES =

noinst_PROGRAMS = y2makefs
y2makefs_SOURCES = y2makefs.cc

y2makefs_LDADD = -ly2 -lycp
y2makefs_LDFLAGS = -L$(libdir)				\
	-L$(srcdir)/../../libycp/src			\
	-Xlinker --whole-archive			\
	$(srcdir)/../../liby2/src/libpy2stdio.la	\
	$(srcdir)/../../liby2/src/libpy2script.la	\
	$(srcdir)/../src/libpy2makefs.la		\
	-Xlinker --no-whole-archive

clean-local:
	rm -f tmp.err.* tmp.out.* *.log *.sum site.exp
