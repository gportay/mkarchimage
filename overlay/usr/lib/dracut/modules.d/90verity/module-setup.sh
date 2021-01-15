#!/bin/bash
#
#  SPDX-License-Identifier: LGPL-2.1+
#
#  This file is part of mkarchlinux.
#
#  mkarchlinux is free software; you can redistribute it and/or modify it
#  under the terms of the GNU Lesser General Public License as published by
#  the Free Software Foundation; either version 2.1 of the License, or
#  (at your option) any later version.

# called by dracut
check() {
	require_binaries \
		$systemdutildir/systemd-veritysetup \
		$systemdutildir/system-generators/systemd-veritysetup-generator \
		|| return 1

	return 0
}

# called by dracut
depends() {
	echo crypt
	return 0
}

# called by dracut
installkernel() {
	hostonly='' instmods dm-verity
}

# called by dracut
install() {
	inst_simple -H /etc/veritytab

	if dracut_module_included "systemd"; then
		inst_multiple -o \
			$systemdsystemunitdir/veritysetup.target \
			$systemdsystemunitdir/sysinit.target.wants/veritysetup.target \
			$systemdutildir/systemd-veritysetup \
			$systemdutildir/system-generators/systemd-veritysetup-generator
	fi
}
