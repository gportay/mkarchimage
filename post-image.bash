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

rm -f /etc/machine-id
if ! [[ -e /boot/efi ]] && ! ln -sf ../efi /boot/efi
then
	echo "Warning: /boot/efi: Cannot create symlink!" >&2
fi
grub-install --no-nvram --removable --target=x86_64-efi --efi-directory=/efi
mkinitcpio -p linux
grub-mkconfig -o /boot/grub/grub.cfg
