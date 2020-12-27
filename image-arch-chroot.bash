#!/bin/bash
# Copyright © 2019 Collabora Ltd.
# SPDX-License-Identifier: MIT

set -e
set -u

if [ $# -lt 2 ]
then
	cat <<EOF >&2
Usage: ${0##*/} FILE MOUNTPOINT [COMMAND [ARGS]]

Mount filesystems on MOUNTPOINT via a loop device using FILE, run COMMAND (or
interactive shell) with root directory set to MOUNTPOINT/root.
EOF
	exit 1
fi

image="$1"
mountpoint="$2"
shift
shift

exec bash losetup.bash "$image" \
     bash mount-root.bash '$dev' "$mountpoint" \
     arch-chroot "$mountpoint" "$@"
