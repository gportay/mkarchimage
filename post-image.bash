#!/bin/bash
#
# Copyright (C) 2020 Gaël PORTAY
#
# SPDX-License-Identifier: GPL-3.0-or-later
#


set -e

cat <<EOF >>/etc/fstab
/dev/sda1       /efi    vfat    defaults,umask=0077,x-systemd.automount,x-systemd.idle-timeout=1min 0       2
EOF

if ! [[ -L /boot/efi ]]
then
	ln -sf ../efi /boot/efi
fi
grub-install --no-nvram --removable --target=x86_64-efi --efi-directory=/efi
cp /boot/initramfs-linux-fallback.img /boot/initramfs-linux.img
grub-mkconfig -o /boot/grub/grub.cfg
