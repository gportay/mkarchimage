#!/bin/bash
#
# Copyright (C) 2020 Gaël PORTAY
#
# SPDX-License-Identifier: GPL-3.0-or-later
#


set -e

sed -e "s,^root:[^:]*:,root::," -i "/etc/shadow"

cat <<EOF >>/etc/fstab
/dev/sda1       /efi    vfat    defaults,umask=0077,x-systemd.automount,x-systemd.idle-timeout=1min 0       2
/dev/sda2       /boot   vfat    defaults                                                            0       2
EOF

if [[ -x grub-install ]]
then
	if ! [[ -e /boot/efi ]] && ! ln -sf ../efi /boot/efi
	then
		echo "Warning: /boot/efi: Cannot create symlink!" >&2
	fi
	grub-install --no-nvram --removable --target=x86_64-efi --efi-directory=/efi
	mkinitcpio -p linux
	grub-mkconfig -o /boot/grub/grub.cfg
	exit
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
