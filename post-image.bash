#!/bin/bash
#
# Copyright (C) 2020-2021 Gaël PORTAY
#
# SPDX-License-Identifier: GPL-3.0-or-later
#

set -e
set -o pipefail

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

options=()

sed -e "s,^root:[^:]*:,root::," -i "/etc/shadow"
cat /etc/shadow

if [[ "$HAVE_USR_VERITY_PARTITION" ]]
then
	parttype="8484680c-9521-48c6-9c11-b0720656f69e"
	read -r data_dev data_partuuid < <(find_device_by_partuuid "$parttype")

	parttype="77ff5f63-e7b6-4633-acf4-1565b864c0e6"
	read -r hash_dev hash_partuuid < <(find_device_by_partuuid "$parttype")

	tune2fs -O "verity,read-only" "$data_dev"
	mount -oremount,ro /usr
	roothash="$(veritysetup format "$data_dev" "$hash_dev" |
		    tee /dev/stderr | \
		    sed -n '/^Root hash:/s,Root hash:[[:blank:]]*,,p')"
	sfdisk --part-attrs "$LOOPDEVICE" "${data_dev##${LOOPDEVICE}p}" GUID:60
	cat <<EOF >>/etc/veritytab
usr PARTUUID=$data_partuuid PARTUUID=$hash_partuuid $roothash auto
EOF
	cat /etc/veritytab

	cat <<EOF >>/etc/fstab.sys
/dev/mapper/usr /usr auto defaults 0 0
EOF
	cat /etc/fstab.sys

	unset parttype data_dev data_partuuid hash_dev hash_partuuid roothash
elif [[ "$HAVE_USR_PARTITION" ]]
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
#
# The initrd images *MUST* be regenerated in case of a separate /usr partition.
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

	# systemd src/shared/dissect-image.c:
	#
	# For /var we insist that the uuid of the partition matches the
	# HMAC-SHA256 of the /var GPT partition type uuid, keyed by machine ID.
	# Why? Unlike the other partitions /var is inherently installation
	# specific, hence we need to be careful not to mount it in the wrong
	# installation. By hashing the partition UUID from /etc/machine-id we
	# can securely bind the partition to the installation.
	# openssl dgst -sha256 -mac hmac -macopt hexkey:0ea3e228b8d8450aa411974c3a6de537 data.bin
	machine_id="$(cat /etc/machine-id)"
	hash="$(printf "\x4d\x21\xb0\x16\xb5\x34\x45\xc2\xa9\xfb\x5c\x16\xe0\x91\xfd\x2d" | \
	        openssl dgst -sha256 -mac hmac -macopt "hexkey:$machine_id" -binary | \
	        xxd -p -l16)"
	# Set UUID version to 4 --- truly random generation
	byte06="$(printf "%02x" "$(((0x${hash:12:2} & 0x0f) | 0x40))")"
	# Set the UUID variant to DCE
	byte08="$(printf "%02x" "$(((0x${hash:16:2} & 0x3f) | 0x80))")"
	hash="${hash:0:12}$byte06${hash:14:2}$byte08${hash:18}"
	uuid="${hash:0:8}-${hash:8:4}-${hash:12:4}-${hash:16:4}-${hash:20:12}"
	sfdisk --part-uuid "$LOOPDEVICE" "${dev##${LOOPDEVICE}p}" "$uuid"

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

if [[ "$HAVE_ROOT_VERITY_PARTITION" ]]
then
	parttype="4f68bce3-e8cd-4db1-96e7-fbcaf984b709"
	read -r data_dev data_partuuid < <(find_device_by_partuuid "$parttype")

	parttype="2c7357ed-ebd2-46d9-aec1-23d437ec2bf5"
	read -r hash_dev hash_partuuid < <(find_device_by_partuuid "$parttype")

	tune2fs -O "verity,read-only" "$data_dev"
	mount -oremount,ro /
	roothash="$(veritysetup format "$data_dev" "$hash_dev" |
		    tee /dev/stderr | \
		    sed -n '/^Root hash:/s,Root hash:[[:blank:]]*,,p')"
	options+=("roothash=$roothash")
	options+=("systemd.verity_root_data=PARTUUID=$data_partuuid")
	options+=("systemd.verity_root_hash=PARTUUID=$hash_partuuid")
	sfdisk --part-attrs "$LOOPDEVICE" "${data_dev##${LOOPDEVICE}p}" GUID:60

	unset parttype data_dev data_partuuid hash_dev hash_partuuid roothash
elif [[ "$READ_ONLY" ]]
then
	parttype="4f68bce3-e8cd-4db1-96e7-fbcaf984b709"
	read -r dev partuuid < <(find_device_by_partuuid "$parttype")

	tune2fs -O read-only "$dev"
	mount -o remount,ro /
	options+=("ro")

	unset parttype dev partuuid
fi

if [[ "$EXTRA_KERNEL_CMDLINE" ]]
then
	options+=("$EXTRA_KERNEL_CMDLINE")
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
options ${options[*]}
EOF
	cat "$dir/loader/entries/arch-$pkgbase.conf"
done
bootctl install --no-variables
