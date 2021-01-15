#!/bin/bash
#
# Copyright (C) 2020-2021 Gaël PORTAY
#
# SPDX-License-Identifier: GPL-3.0-or-later
#

# https://wiki.archlinux.org/index.php/installation_guide

set -e

rm -f /var/cache/pacman/pkg/*.pkg.tar.*

ln -sf "/usr/share/zoneinfo/${HAVE_TIMEZONE:-America/Montreal}" /etc/localtime

IFS=: read -a locales <<<"${HAVE_LOCALES:-en_US.UTF-8 UTF-8}"
for i in "${locales[@]}"
do
	sed -e "/^#${i//./\\.}/s,^#,," -i /etc/locale.gen
done
sed -e '/^#/d' /etc/locale.gen
locale-gen
read -a lang <<<"${locales[0]}"
echo "LANG=${lang[0]}" >/etc/locale.conf
cat /etc/locale.conf

hostname="${HAVE_HOSTNAME:-archlinux}"
IFS=. read -a domains <<<"$hostname"
cat <<EOF >/etc/hosts
# Static table lookup for hostnames.
# See hosts(5) for details.
127.0.0.1	localhost
::1		localhost
127.0.1.1	$hostname.localdomain	${domains[0]}
EOF
cat /etc/hosts

echo "$hostname" >/etc/hostname
cat /etc/hostname

systemctl enable systemd-networkd.service
systemctl enable systemd-resolved.service

pacman -Q
