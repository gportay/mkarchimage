#
# Copyright (C) 2020 Gaël PORTAY
#
# SPDX-License-Identifier: GPL-3.0-or-later
#

SHELL = /bin/bash

QEMU ?= qemu-system-x86_64
QEMU += -enable-kvm -m 4G -machine q35 -smp 4 -cpu host
QEMU += -nographic
QEMU += -spice port=5924,disable-ticketing -device virtio-serial-pci -device virtserialport,chardev=spicechannel0,name=com.redhat.spice.0 -chardev spicevmc,id=spicechannel0,name=vdagent
QEMU += -serial mon:stdio
QEMU += -drive format=raw,file=/usr/share/ovmf/x64/OVMF_CODE.fd,readonly,if=pflash -drive format=raw,file=OVMF_VARS.fd,if=pflash

.PHONY: all
all: disk.img

.PHONY: run-qemu
run-qemu: | disk.img OVMF_VARS.fd
	$(QEMU) $(QEMUFLAGS) -drive format=raw,file=disk.img

.PHONY: run-remote-viewer
run-remote-viewer:
	remote-viewer spice://localhost:5924

.PRECIOUS: OVMF_VARS.fd
OVMF_VARS.fd: /usr/share/ovmf/x64/OVMF_VARS.fd
	cp $< $@

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
rootfs.tar: override PACKAGES += systemd-resolvconf
rootfs.tar: | pacman.conf rootfs
	EUID=0 sudo -E \
	     bash pacstrap -C pacman.conf rootfs base linux grub efibootmgr $(PACKAGES) --needed
	sudo bash arch-chroot rootfs \
	     bash <post-rootfs.bash
	sudo rsync -av overlay/. rootfs/.
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

.PHONY: image-overlay
image-overlay: | disk.img mnt
	sudo bash image-mount-root.bash disk.img mnt \
	     rsync -av overlay/. mnt/.

.PHONY: overlay
overlay: | rootfs.tar rootfs
	sudo rsync -av overlay/. rootfs/.

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
