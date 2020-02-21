#
# Copyright (C) 2020 Gaël PORTAY
#
# SPDX-License-Identifier: GPL-3.0-or-later
#

SHELL = /bin/bash

.PHONY: all
all: disk.img

.PRECIOUS: disk.img
disk.img: | disk.sfdisk rootfs.tar mnt
	rm -f $@.tmp
	fallocate --length 8G $@.tmp
	sfdisk $@.tmp <disk.sfdisk
	sfdisk --dump $@.tmp
	sudo bash image-mkfs-all.bash $@.tmp mnt
	sudo bash image-tar-root.bash $@.tmp mnt rootfs.tar
	sudo bash image-arch-chroot.bash $@.tmp mnt bash <post-image.bash
	mv $@.tmp $@

.PRECIOUS: rootfs.tar
rootfs.tar: | pacman.conf rootfs
	EUID=0 sudo -E \
	     bash pacstrap -C pacman.conf rootfs base linux grub efibootmgr --needed
	sudo bash arch-chroot rootfs \
	     bash <post-rootfs.bash
	sudo tar cf $@ -C rootfs .

rootfs mnt:
	mkdir -p $@

.PHONY: image-arch-chroot
image-arch-chroot: TERM = linux
image-arch-chroot: | disk.img mnt
	sudo bash image-arch-chroot.bash disk.img mnt

.PHONY: arch-chroot
arch-chroot: TERM = linux
arch-chroot: | rootfs
	sudo bash arch-chroot rootfs

.PHONY: post-image
post-image: | disk.img mnt
	sudo bash image-arch-chroot.bash disk.img mnt \
	     bash <post-image.bash

.PHONY: image-mount
image-mount: | disk.img mnt
	sudo bash image-mount-root.bash disk.img mnt

.PHONY: grub-install-removable
grub-install-removable: | disk.img mnt
	sudo bash image-arch-chroot.bash disk.img mnt \
	     grub-install --no-nvram --removable --target=x86_64-efi --efi-directory=/efi

.PHONY: grub-mkconfig
grub-mkconfig: | disk.img mnt
	sudo bash image-arch-chroot.bash disk.img mnt \
	     grub-mkconfig -o /boot/grub/grub.cfg

.PHONY: post-rootfs
post-rootfs: | rootfs.tar rootfs
	sudo bash arch-chroot rootfs \
	     bash <post-rootfs.bash

.PHONY: clean
clean:
	rm -f disk.img rootfs.tar pacman.conf
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
