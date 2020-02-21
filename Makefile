#
# Copyright (C) 2020 Gaël PORTAY
#
# SPDX-License-Identifier: GPL-3.0-or-later
#

SHELL = /bin/bash

.PHONY: all
all: rootfs.tar

.PRECIOUS: rootfs.tar
rootfs.tar: | pacman.conf rootfs
	EUID=0 sudo -E \
	     bash pacstrap -C pacman.conf rootfs base --needed
	sudo bash arch-chroot rootfs \
	     bash <post-rootfs.bash
	sudo tar cf $@ -C rootfs .

rootfs:
	mkdir -p $@

.PHONY: arch-chroot
arch-chroot: TERM = linux
arch-chroot: | rootfs
	sudo bash arch-chroot rootfs

.PHONY: post-rootfs
post-rootfs: | rootfs.tar rootfs
	sudo bash arch-chroot rootfs \
	     bash <post-rootfs.bash

.PHONY: clean
clean:
	rm -f rootfs.tar pacman.conf
	sudo rm -Rf rootfs

.PRECIOUS: pacman.conf.in
pacman.conf.in:
	wget https://git.archlinux.org/pacman.git/plain/etc/pacman.conf.in

.PRECIOUS: pacman.conf
pacman.conf: pacman.conf.in
	sed -e 's,@ROOTDIR@,/,' \
	    -e 's,@sysconfdir@,/etc,' \
	    -e 's,@localstatedir@,/var,' \
		<$< >$@.tmp
	if grep -q '@[[:alnum:]_]\+@' $@.tmp; then \
		echo "Error: Remaining substitutions!" >&2; \
		exit 1; \
	fi
	@for repo in core extra community; do \
		echo >>$@.tmp; \
		echo "[$$repo]" >>$@.tmp; \
		echo "SigLevel = Optional TrustAll" >>$@.tmp; \
		echo "Include = mirrorlist" >>$@.tmp; \
	done
	mv $@.tmp $@
