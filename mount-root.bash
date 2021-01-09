#!/bin/bash
#
# Copyright (C) 2020-2021 Gaël PORTAY
#
# SPDX-License-Identifier: GPL-3.0-or-later
#

set -e
set -u

if [ $# -lt 2 ]
then
	cat <<EOF >&2
Usage: ${0##*/} DEVICE MOUNTPOINT [COMMAND] [ARGS]

Mount all filesystems on MOUNTPOINT using DEVICE, run COMMAND (or interactive
shell) and unmount it on exit.
EOF
	exit 1
fi

dev="$1"
mountpoint="$2"
declare -A wheres
for what in "${dev}"p*
do
	[[ -b "$what" ]] || continue

	read -r parttype < <(lsblk --output PARTTYPE --noheadings "$what")
	if [[ ! "${parttype:-}" ]]
	then
		echo "$what: Invalid partition" >&2
		continue
	fi

	case "${parttype:-}" in
	# EFI System Partition
	#
	# VFAT
	#
	# The ESP used for the current boot is automatically mounted to /efi/
	# (or /boot/ as fallback), unless a different partition is mounted
	# there (possibly via /etc/fstab, or because the Extended Boot Loader
	# Partition — see below — exists) or the directory is non-empty on the
	# root disk. This partition type is defined by the UEFI Specification.
	c12a7328-f81f-11d2-ba4b-00a0c93ec93b) # EFI System Partition
		where="/efi"
		;;

	# Extended Boot Loader Partition
	#
	# Typically VFAT
	#
	# The Extended Boot Loader Partition (XBOOTLDR) used for the current
	# boot is automatically mounted to /boot/, unless a different partition
	# is mounted there (possibly via /etc/fstab) or the directory is
	# non-empty on the root disk.  This partition type is defined by the
	# Boot Loader Specification.
	bc13c2ff-59e6-4262-a352-b275fd6f7172) # Extended Boot Loader Partition
		where="/boot"
		;;

	# Variable Data Partition
	#
	# Any native, optionally in LUKS
	#
	# The first partition with this type UUID on the disk containing the
	# root partition is automatically mounted to /var/ — under the
	# condition that its partition UUID matches the first 128 bit of
	# HMAC-SHA256(machine-id, 0x4d21b016b53445c2a9fb5c16e091fd2d) (i.e. the
	# SHA256 HMAC hash of the binary type UUID keyed by the machine ID as
	# read from /etc/machine-id. This special requirement is made because
	# /var/ (unlike the other partition types listed here) is inherently
	# private to a specific installation and cannot possibly be shared
	# between multiple OS installations on the same disk, and thus should
	# be bound to a specific instance of the OS, identified by its machine
	# ID. If the partition is encrypted with LUKS, the device mapper file
	# will be named /dev/mapper/var.
	4d21b016-b534-45c2-a9fb-5c16e091fd2d) # Variable Data Partition
		where="/var"
		;;

	# /usr/ Partition
	#
	# Any native, optionally in LUKS.
	#
	# Similar semantics to root partition, but just the /usr/ partition.
	8484680c-9521-48c6-9c11-b0720656f69e) # /usr/ Partition (x86-64)
		where="/usr"
		;;

	# Swap
	#
	# Swap
	#
	# All swap partitions on the disk containing the root partition are
	# automatically enabled.
	0657fd6d-a4ab-43c4-84e5-0933c84b4f4f) # Swap
		# Ignored.
		;;

	# Root Partition
	#
	# Any native, optionally in LUKS
	#
	# On systems with matching architecture, the first partition with this
	# type UUID on the disk containing the active EFI ESP is automatically
	# mounted to the root directory /. If the partition is encrypted with
	# LUKS or has dm-verity integrity data (see below), the device mapper
	# file will be named /dev/mapper/root.
	4f68bce3-e8cd-4db1-96e7-fbcaf984b709) # Root Partition (x86-64)
		where="/"
		;;

	# Home Partition
	#
	# Any native, optionally in LUKS.
	#
	# The first partition with this type UUID on the disk
	# containing the root partition is automatically mounted to
	# /home/. If the partition is encrypted with LUKS, the device
	# mapper file will be named /dev/mapper/home.
	933ac7e1-2eb4-4f13-b844-0e14e2aef915) # Home Partition
		where="/home"
		;;

	*)
		echo "$what: $parttype: Ignoring partition type" >&2
		;;
	esac

	if [[ "${where:-}" ]]
	then
		wheres["$where"]="$what"
	fi

	unset where parttype
done

if [[ ! "${wheres[/]:-}" ]]
then
	echo "$1: No such / partition" >&2
	exit 1
fi

mount "${wheres[/]}" "$mountpoint"
trap 'set +e; umount -Rf "$mountpoint"; set -e' 0
unset wheres[/]

for where in "${!wheres[@]}"
do
	mkdir -p "$mountpoint$where"
	mount "${wheres[$where]}" "$mountpoint$where"
done
mount | grep "$mountpoint"

shift
shift

eval "${@:-bash}"
