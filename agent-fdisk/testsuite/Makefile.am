#
# Makefile.am for y2scr/ag_fdisk/testsuite
#

AUTOMAKE_OPTIONS = dejagnu

INCLUDES = -I$(includedir)

noinst_PROGRAMS = runfdisk
runfdisk_SOURCES = runfdisk.cc

runfdisk_LDADD = -lscr -ly2 -lycp -lcrypt
runfdisk_LDFLAGS = -L$(libdir)	\
	-Xlinker --whole-archive	\
	$(plugindir)/libpy2stdio.la	\
	$(plugindir)/libpy2script.la	\
	../src/libpy2ag_fdisk.la	\
	-Xlinker --no-whole-archive

