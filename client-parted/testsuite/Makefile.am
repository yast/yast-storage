#
# Makefile.am for core/client-parted/testsuite
#

AUTOMAKE_OPTIONS = dejagnu

INCLUDES =

noinst_PROGRAMS = y2parted
y2parted_SOURCES = y2parted.cc

y2parted_LDADD = -ly2 -lycp
y2parted_LDFLAGS = -L$(libdir)				\
	-L$(srcdir)/../../libycp/src			\
	-Xlinker --whole-archive			\
	$(srcdir)/../../liby2/src/libpy2stdio.la	\
	$(srcdir)/../../liby2/src/libpy2script.la	\
	$(srcdir)/../src/libpy2parted.la				\
	-Xlinker --no-whole-archive

clean-local:
	rm -f tmp.err.* tmp.out.* *.log *.sum site.exp
