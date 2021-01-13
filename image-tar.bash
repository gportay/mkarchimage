#!/bin/bash
#
# Copyright (C) 2020-2021 Gaël PORTAY
#
# SPDX-License-Identifier: GPL-3.0-or-later
#

set -e
set -u

if [ $# -lt 3 ]
then
	cat <<EOF >&2
Usage: ${0##*/} FILE MOUNTPOINT ARCHIVE [TAR_OPTIONS]

Extract files from ARCHIVE to filesystems via loop device using FILE.
EOF
	exit 1
fi

image="$1"
mountpoint="$2"
archive="$3"
shift
shift
shift

exec bash losetup.bash "$image" \
     bash mount.bash '$dev' "$mountpoint" tar xf "$archive" -C "$mountpoint" "$@"
