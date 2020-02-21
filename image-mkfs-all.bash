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
Usage: ${0##*/} FILE

Create all filesystems via loop device using FILE.
EOF
	exit 1
fi

file="$1"
shift

exec bash losetup.bash "$file" \
     bash mkfs-all.bash '$dev' "$@"
