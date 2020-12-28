#  SPDX-License-Identifier: LGPL-2.1+
#
#  This file is part of mkarchimage.
#
#  systemd is free software; you can redistribute it and/or modify it
#  under the terms of the GNU Lesser General Public License as published by
#  the Free Software Foundation; either version 2.1 of the License, or
#  (at your option) any later version.

#  SPDX-License-Identifier: GFDL-1.3
#
#  This code is based on:
#  https://wiki.archlinux.org/index.php/working_with_the_serial_console#Resizing_a_terminal

if ! which resize >/dev/null 2&>1
then
resize() {
	if [[ -t 0 && $# -eq 0 ]]
	then
		local IFS='[;' escape geometry x y
		echo -e -n '\e7\e[r\e[999;999H\e[6n\e8' >"$(tty)"
		read -sd R escape geometry <"$(tty)"
		x=${geometry##*;} y=${geometry%%;*}
		stty cols "$x" rows "$y"
		cat <<EOF
COLUMNS=$x;
LINES=$y;
export COLUMNS LINES;
EOF
	else
		return 1
	fi
}
fi

#  Copyright 2015, Matthieu Gaignière
#
#  This code is based on:
#  http://lightcode.github.io/OVM/console.html#bonus-resize-automatically-the-terminal

if [ "$(tty)" == "/dev/ttyS0" ]
then
	eval "$(resize)"
fi
