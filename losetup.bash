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
Usage: ${0##*/} FILE [COMMAND] [ARGS]

Set up a loop device using FILE, run the COMMAND (or interactive shell) and
detach it on exit.
EOF
	exit 1
fi

dev="$(losetup -vfP --show "$1")"
trap "losetup -vd $dev" 0

shift

LOOPDEVICE="$dev"
export LOOPDEVICE

eval "${@:-bash}"
