#!/bin/bash
#
# Copyright (C) 2020-2021 Gaël PORTAY
#
# SPDX-License-Identifier: GPL-3.0-or-later
#

set -e

find_device_by_partuuid() {
	local what

	for what in "${LOOPDEVICE}"p*
	do
		local parttype partuuid
		[[ -b "$what" ]] || continue

		read -r parttype partuuid < <(lsblk --output PARTTYPE,PARTUUID --noheadings "$what")
		if [[ "${parttype:-}" != "$1" ]] || \
		   [[ ! "${partuuid:-}" ]]
		then
			continue
		fi

		echo "$what" "$partuuid"
		return 0
	done

	echo "PARTUUID=$1: No such device" >&2
	return 1
}

sed -e "s,^root:[^:]*:,root::," -i "/etc/shadow"
cat /etc/shadow

cat <<EOF >>/etc/fstab
/dev/sda1       /efi    vfat    defaults,umask=0077,x-systemd.automount,x-systemd.idle-timeout=1min 0       2
/dev/sda2       /boot   vfat    defaults                                                            0       2
EOF
cat /etc/fstab

if [[ "$HAVE_USR_PARTITION" ]]
then
	parttype="8484680c-9521-48c6-9c11-b0720656f69e"
	read -r dev partuuid < <(find_device_by_partuuid "$parttype")

	cat <<EOF >/etc/fstab.sys
# Static information about the filesystems.
# See fstab(5) for details.

# <file system> <dir> <type> <options> <dump> <pass>
PARTUUID=$partuuid /usr auto defaults 0 0
EOF
	cat /etc/fstab.sys

	unset parttype dev partuuid
fi

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
cat /efi/loader/loader.conf

dir="/boot"
if ! mountpoint "$dir"
then
	cp /boot/initramfs-linux.img /efi
	cp /boot/vmlinuz-linux /efi
	dir="/efi"
fi

if [[ "$HAVE_VARIABLE_DATA_PARTITION" ]]
then
	parttype="4d21b016-b534-45c2-a9fb-5c16e091fd2d"
	read -r dev partuuid < <(find_device_by_partuuid "$parttype")

	cat <<EOF >>/etc/fstab
PARTUUID=$partuuid /var ext4 defaults 0 0
EOF
	cat /etc/fstab

	unset parttype dev partuuid
fi

if [[ "$HAVE_OTHER_DATA_PARTITION" ]] && [[ "$OTHER_DATA_FILESYSTEM_MOUNTPOINT" ]]
then
	parttype="0fc63daf-8483-4772-8e79-3d69d8477de4"
	read -r dev partuuid < <(find_device_by_partuuid "$parttype")

	mountpoint="$OTHER_DATA_FILESYSTEM_MOUNTPOINT"
	mkdir -p "$mountpoint"

	cat <<EOF >>/etc/fstab
PARTUUID=$partuuid $mountpoint ext4 defaults 0 0
EOF
	cat /etc/fstab

	unset mountpoint parttype dev partuuid
fi

if [[ "$READ_ONLY" ]]
then
	parttype="4f68bce3-e8cd-4db1-96e7-fbcaf984b709"
	read -r dev partuuid < <(find_device_by_partuuid "$parttype")

	tune2fs -O read-only "$dev"
	mount -o remount,ro /
	options+=("ro")

	unset parttype dev partuuid
fi

mkdir -p "$dir/loader/entries"
for i in /boot/initramfs-*.img
do
	[[ -e "$i" ]] || continue
	pkgbase="${i%.img}"
	pkgbase="${pkgbase#/boot/initramfs-}"
	IFS=- read -a pkgbases <<<"$pkgbase"
	cat <<EOF >"$dir/loader/entries/arch-$pkgbase.conf"
title   Arch ${pkgbases[*]^}
linux   /vmlinuz-${pkgbases[0]}
initrd  /initramfs-$pkgbase.img
options ${options[*]} console=ttyS0
EOF
	cat "$dir/loader/entries/arch-$pkgbase.conf"
done
bootctl install --no-variables
