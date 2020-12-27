#!/bin/bash
#
# Copyright (C) 2020 Gaël PORTAY
#
# SPDX-License-Identifier: GPL-3.0-or-later
#

set -e
set -u

if [ $# -lt 2 ]
then
	cat <<EOF >&2
Usage: ${0##*/} DEVICE MOUNTPOINT [COMMAND] [ARGS]

Mount root, boot and efi filesystems on MOUNTPOINT, and MOUNTPOINT/efi using
DEVICE, run COMMAND (or interactive shell) and unmount it on exit.
EOF
	exit 1
fi

dev="$1"
mountpoint="$2"
mount "${dev}p3" "$mountpoint"
trap 'set +e; umount -Rf "$mountpoint"; set -e' 0
mkdir -p "$mountpoint/boot"
mount "${dev}p2" "$mountpoint/boot"
mkdir -p "$mountpoint/efi"
mount "${dev}p1" "$mountpoint/efi"

shift
shift

eval "${@:-bash}"
