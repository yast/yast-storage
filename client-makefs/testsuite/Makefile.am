#
# Makefile.am for storage/client-makefs/testsuite
#

AUTOMAKE_OPTIONS = dejagnu

INCLUDES =

noinst_PROGRAMS = y2makefs
y2makefs_SOURCES = y2makefs.cc

y2makefs_LDADD = -ly2 -lycp
y2makefs_LDFLAGS = -L$(libdir)				\
	-Xlinker --whole-archive			\
	$(plugindir)/libpy2stdio.la			\
	$(srcdir)/../src/libpy2makefs.la		\
	-Xlinker --no-whole-archive

clean-local:
	rm -f tmp.err.* tmp.out.* *.log *.sum site.exp
