
YBINDIR=/usr/lib/YaST2/bin

all: fdisk

fdisk: fdisk/fdisk/fdisk

fdisk/fdisk/fdisk: yast.fdisk.dif  yast.fdisk.tar.gz
	tar xvpfz yast.fdisk.tar.gz
	cat yast.fdisk.dif | (cd fdisk && patch -p0 )
	make -C fdisk/fdisk fdisk

install: all
	install -d $(DESTDIR)$(YBINDIR)
	install -o root -g root -m 0755 -s fdisk/fdisk/fdisk $(DESTDIR)$(YBINDIR)/fdisk

install-strip: install

check:

clean:
	rm -rf fdisk

distdir: Makefile yast.fdisk.dif  yast.fdisk.tar.gz
	cp -av Makefile yast.fdisk.dif  yast.fdisk.tar.gz $(distdir)

