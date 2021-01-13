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
Usage: ${0##*/} FILE MOUNTPOINT [COMMAND] [ARGS]

Mount filesystems on MOUNTPOINT via a loop device using FILE, run COMMAND (or
interactive shell) and unmount it on exit.
EOF
	exit 1
fi

image="$1"
mountpoint="$2"
shift
shift

exec bash losetup.bash "$image" \
     bash mount.bash '$dev' "$mountpoint" "$@"
