#!/bin/bash
#
# Copyright (C) 2020 Gaël PORTAY
#
# SPDX-License-Identifier: GPL-3.0-or-later
#

set -e
set -u

if [ $# -lt 1 ]
then
	cat <<EOF >&2
Usage: ${0##*/} DEVICE

Create all filesystems in DEVICE partitions.
EOF
	exit 1
fi

loopdev="$1"

mkfs.msdos "$loopdev"p1
mkfs.ext4 "$loopdev"p2
