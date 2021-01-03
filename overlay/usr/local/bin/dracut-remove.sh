#!/usr/bin/env bash
#
#  SPDX-License-Identifier: LGPL-2.1+
#
#  This file is part of mkarchlinux.
#
#  mkarchlinux is free software; you can redistribute it and/or modify it
#  under the terms of the GNU Lesser General Public License as published by
#  the Free Software Foundation; either version 2.1 of the License, or
#  (at your option) any later version.

#  SPDX-License-Identifier: GFDL-1.3
#
#  This code is based on:
#  https://wiki.archlinux.org/index.php/Dracut#Generate_a_new_initramfs_on_kernel_upgrade

while read -r line; do
	if [[ "$line" == 'usr/lib/modules/'+([^/])'/pkgbase' ]]; then
		read -r pkgbase < "/${line}"
		rm -f "/boot/vmlinuz-${pkgbase}" "/boot/initramfs-${pkgbase}.img" "/boot/initramfs-${pkgbase}-fallback.img"
	fi
done
