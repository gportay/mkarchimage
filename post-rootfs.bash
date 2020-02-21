#!/bin/bash
#
# Copyright (C) 2020 Gaël PORTAY
#
# SPDX-License-Identifier: GPL-3.0-or-later
#

# https://wiki.archlinux.org/index.php/installation_guide

set -e

rm -f /var/cache/pacman/pkg/*.pkg.tar.*

ln -sf /usr/share/zoneinfo/America/Montreal /etc/localtime

sed -e '/^#en_US\.UTF-8 UTF-8/s,^#,,' -i /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 >/etc/locale.conf

cat <<EOF >/etc/hosts
127.0.0.1	localhost
::1		localhost
127.0.1.1	archlinux.localdomain	archlinux
EOF

echo "archlinux" >/etc/hostname

systemctl enable systemd-networkd.service
systemctl enable systemd-resolved.service
