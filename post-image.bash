#!/bin/bash
#
# Copyright (C) 2020-2021 Gaël PORTAY
#
# SPDX-License-Identifier: GPL-3.0-or-later
#


set -e

sed -e "s,^root:[^:]*:,root::," -i "/etc/shadow"

cat <<EOF >>/etc/fstab
/dev/sda1       /efi    vfat    defaults,umask=0077,x-systemd.automount,x-systemd.idle-timeout=1min 0       2
/dev/sda2       /boot   vfat    defaults                                                            0       2
EOF

# Run pacman hook for dracut manually as it is a part of the overlay which is
# install after the rootfs is built with pacstrap.
if [[ -x /usr/bin/dracut ]]
then
	compgen -G usr/lib/modules/"*"/pkgbase | dracut-install.sh
fi

mkdir -p /efi/loader
cat <<EOF >/efi/loader/loader.conf
default  arch.conf
timeout  4
console-mode max
editor   no
EOF

dir="/boot"
if ! mountpoint "$dir"
then
	cp /boot/initramfs-linux.img /efi
	cp /boot/vmlinuz-linux /efi
	dir="/efi"
fi

mkdir -p "$dir/loader/entries"
cat <<EOF >"$dir/loader/entries/arch.conf"
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=/dev/sda3 rw console=ttyS0
EOF
bootctl install
