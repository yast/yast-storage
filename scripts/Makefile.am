#
# Makefile.am for storage/scripts
#

ybin_SCRIPTS =			\
	check.boot 		\
	create_udev_cdrom_rules

EXTRA_DIST = $(ybin_SCRIPTS)

install-exec-am:
	mkdir -p $(DESTDIR)/usr/sbin
	ln -sf /usr/lib/YaST2/bin/create_udev_cdrom_rules $(DESTDIR)/usr/sbin
