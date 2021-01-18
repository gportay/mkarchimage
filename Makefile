#
# Copyright (C) 2020-2021 Gaël PORTAY
#
# SPDX-License-Identifier: GPL-3.0-or-later
#

SHELL = /bin/bash

QEMU ?= qemu-system-x86_64
QEMU += -enable-kvm -m 4G -machine q35 -smp 4 -cpu host
ifndef NO_SPICE
QEMU += -vga virtio -display egl-headless,gl=on
QEMU += -spice port=5924,disable-ticketing -device virtio-serial-pci -device virtserialport,chardev=spicechannel0,name=com.redhat.spice.0 -chardev spicevmc,id=spicechannel0,name=vdagent
endif
QEMU += -serial mon:stdio
ifndef NO_OVMF
QEMU += -drive format=raw,file=/usr/share/ovmf/x64/OVMF_CODE.fd,readonly,if=pflash -drive format=raw,file=OVMF_VARS.fd,if=pflash
endif

PACKAGES += dracut

# Strip quotes and then whitespaces
qstrip = $(strip $(subst ",,$(1)))

-include .config

.SILENT: _all
_all: all | .config

.SILENT: .config
.config:
	echo "Please configure first (e.g. "make menuconfig"))" >&2
	false

.PHONY: menuconfig
menuconfig:
	kconfig-mconf Kconfig

.PHONY: nconfig
nconfig:
	kconfig-nconf Kconfig

.PHONY: config
config:
	kconfig-conf --oldaskconfig Kconfig

.PHONY: oldconfig allnoconfig allyesconfig alldefconfig randconfig listnewconfig olddefconfig
oldconfig allnoconfig allyesconfig alldefconfig randconfig listnewconfig olddefconfig:
	kconfig-conf --$@ Kconfig

.PHONY: savedefconfig
savedefconfig:
	kconfig-conf --$@=defconfig Kconfig

.PHONY: defconfig
defconfig:
	kconfig-conf --$@=configs/qemu_defconfig Kconfig

$(foreach defconfig,$(patsubst configs/%,%,$(wildcard configs/*_defconfig)),$(defconfig)):
%_defconfig:
	kconfig-conf --defconfig=configs/$@ Kconfig

PACKAGES += $(call qstrip,$(CONFIG_PACKAGES))
EXTRA_KERNEL_CMDLINE += $(call qstrip,$(CONFIG_EXTRA_KERNEL_CMDLINE))
export EXTRA_KERNEL_CMDLINE
HAVE_TIMEZONE = $(call qstrip,$(CONFIG_TIMEZONE))
HAVE_LOCALES = $(call qstrip,$(CONFIG_LOCALES))
HAVE_HOSTNAME = $(call qstrip,$(CONFIG_HOSTNAME))
IMAGE_SIZE = $(call qstrip,$(CONFIG_IMAGE_SIZE))
ifeq ($(CONFIG_READ_ONLY),y)
READ_ONLY = y
export READ_ONLY
endif
ifeq ($(CONFIG_HAVE_ROOT_VERITY_PARTITION),y)
HAVE_ROOT_VERITY_PARTITION = y
ROOT_VERITY_PARTITION_NAME = $(call qstrip,$(CONFIG_ROOT_VERITY_PARTITION_NAME))
export HAVE_ROOT_VERITY_PARTITION ROOT_VERITY_PARTITION_NAME
endif
ifeq ($(CONFIG_HAVE_VARIABLE_DATA_PARTITION),y)
PACKAGES += xxd
HAVE_VARIABLE_DATA_PARTITION = y
VARIABLE_DATA_PARTITION_NAME = $(call qstrip,$(CONFIG_VARIABLE_DATA_PARTITION_NAME))
export HAVE_VARIABLE_DATA_PARTITION VARIABLE_DATA_PARTITION_NAME
endif
ifeq ($(CONFIG_HAVE_USR_PARTITION),y)
HAVE_USR_PARTITION = y
USR_PARTITION_NAME = $(call qstrip,$(CONFIG_USR_PARTITION_NAME))
export HAVE_USR_PARTITION USR_PARTITION_NAME
endif
ifeq ($(CONFIG_HAVE_USR_VERITY_PARTITION),y)
HAVE_USR_VERITY_PARTITION = y
USR_VERITY_PARTITION_NAME = $(call qstrip,$(CONFIG_USR_VERITY_PARTITION_NAME))
export HAVE_USR_VERITY_PARTITION USR_VERITY_PARTITION_NAME
endif
ifeq ($(CONFIG_HAVE_SERVER_DATA_PARTITION),y)
HAVE_SERVER_DATA_PARTITION = y
SERVER_DATA_PARTITION_NAME = $(call qstrip,$(CONFIG_SERVER_DATA_PARTITION_NAME))
export HAVE_SERVER_DATA_PARTITION SERVER_DATA_PARTITION_NAME
endif
ifeq ($(CONFIG_HAVE_TEMPORARY_DATA_PARTITION),y)
HAVE_TEMPORARY_DATA_PARTITION = y
TEMPORARY_DATA_PARTITION_NAME = $(call qstrip,$(CONFIG_TEMPORARY_DATA_PARTITION_NAME))
endif
ifeq ($(CONFIG_HAVE_OTHER_DATA_PARTITION),y)
HAVE_OTHER_DATA_PARTITION = y
OTHER_DATA_PARTITION_NAME = $(call qstrip,$(CONFIG_OTHER_DATA_PARTITION_NAME))
OTHER_DATA_FILESYSTEM_MOUNTPOINT = $(call qstrip,$(CONFIG_OTHER_DATA_FILESYSTEM_MOUNTPOINT))
export HAVE_OTHER_DATA_PARTITION OTHER_DATA_PARTITION_NAME OTHER_DATA_FILESYSTEM_MOUNTPOINT
endif
ifeq ($(CONFIG_HAVE_SWAP_PARTITION),y)
HAVE_SWAP_PARTITION = y
SWAP_PARTITION_NAME = $(call qstrip,$(CONFIG_SWAP_PARTITION_NAME))
export HAVE_SWAP_PARTITION SWAP_PARTITION_NAME
endif
ifeq ($(CONFIG_HAVE_HOME_PARTITION),y)
HAVE_HOME_PARTITION = y
HOME_PARTITION_NAME = $(call qstrip,$(CONFIG_HOME_PARTITION_NAME))
export HAVE_HOME_PARTITION HOME_PARTITION_NAME
endif
export HAVE_TIMEZONE HAVE_LOCALES HAVE_HOSTNAME

ifeq ($(CONFIG_HAVE_HOME_PARTITION)$(CONFIG_ROOT_PARTITION_SIZE),y"")
CONFIG_ROOT_PARTITION_SIZE = "2G"
$(warning CONFIG_ROOT_PARTITION_SIZE defaults to $(CONFIG_ROOT_PARTITION_SIZE))
endif

.PHONY: help
.SILENT: help
help:
	echo  'Cleaning targets:'
	echo  '  clean           - Remove most generated files but keep the config and'
	echo  '                    enough build support to build external modules'
	echo  '  mrproper        - Remove all generated files + config + various backup files'
	echo  ''
	echo  'Configuration targets:'
	echo  '  config          - Update current config utilising a line-oriented program'
	echo  '  nconfig         - Update current config utilising a ncurses menu based'
	echo  '                    program'
	echo  '  menuconfig      - Update current config utilising a menu based program'
	echo  '  oldconfig       - Update current config utilising a provided .config as base'
	echo  '  defconfig       - New config with default from ARCH supplied defconfig'
	echo  '  savedefconfig   - Save current config as ./defconfig (minimal config)'
	echo  '  allnoconfig     - New config where all options are answered with no'
	echo  '  allyesconfig    - New config where all options are accepted with yes'
	echo  '  alldefconfig    - New config with all symbols set to default'
	echo  '  randconfig      - New config with random answer to all options'
	echo  '  listnewconfig   - List new options'
	echo  '  olddefconfig    - Same as oldconfig but sets new symbols to their'
	echo  '                    default value without prompting'
	echo  'Other generic targets:'
	echo  '  all             - Build all targets marked with [*]'
	echo  '* rootfs.tar      - Build the rootfs archive'
	echo  '* disk.img        - Build the disk image'
	echo  '  disk.img.zip    - Build the zip archive for Etcher'
	echo  '  run-qemu        - Run the disk image within Qemu'
	echo  '  run-remote-viewer'
	echo  '                  - Run the remote desktop client'

.PHONY: all
all: disk.img

.PHONY: run-qemu
run-qemu: | disk.img OVMF_VARS.fd
	$(QEMU) $(QEMUFLAGS) -drive format=raw,file=disk.img

.PHONY: run-remote-viewer
run-remote-viewer:
	remote-viewer spice://localhost:5924

.PRECIOUS: OVMF_VARS.fd
OVMF_VARS.fd: /usr/share/ovmf/x64/OVMF_VARS.fd
	cp $< $@

.PRECIOUS: disk.img
disk.img: EUID = 0
disk.img: | disk.sfdisk rootfs.tar mnt
	rm -f $@.tmp
	fallocate --length $(IMAGE_SIZE) $@.tmp
	sfdisk $@.tmp <disk.sfdisk
	sfdisk --dump $@.tmp
	sudo -E bash image-mkfs.bash $@.tmp mnt
	sudo -E bash image-tar.bash $@.tmp mnt rootfs.tar
	sudo -E bash image-arch-chroot.bash $@.tmp mnt \
		bash <post-image.bash
	mv $@.tmp $@

.PRECIOUS: rootfs.tar
rootfs.tar: EUID = 0
rootfs.tar: override PACKAGES += systemd-resolvconf
rootfs.tar: | pacman.conf rootfs
	sudo -E bash pacstrap -C pacman.conf rootfs $(PACKAGES) --needed
	sudo -E arch-chroot rootfs \
	        bash <post-rootfs.bash
	sudo -E rsync -av overlay/. rootfs/.
	sudo -E tar cf $@ -C rootfs .

rootfs mnt .meta:
	mkdir -p $@

.PHONY: image-arch-chroot
image-arch-chroot: EUID = 0
image-arch-chroot: TERM = linux
image-arch-chroot: | disk.img mnt
	sudo -E bash image-arch-chroot.bash disk.img mnt

.PHONY: arch-chroot
arch-chroot: EUID = 0
arch-chroot: TERM = linux
arch-chroot: | rootfs
	sudo -E bash arch-chroot rootfs

.PHONY: post-image
post-image: EUID = 0
post-image: | disk.img mnt
	sudo -E bash image-arch-chroot.bash disk.img mnt \
	        bash <post-image.bash

.PHONY: image-mount
image-mount: | disk.img mnt
	sudo -E bash image-mount.bash disk.img mnt

.PHONY: post-rootfs
post-rootfs: EUID = 0
post-rootfs: | rootfs.tar rootfs
	sudo -E bash arch-chroot rootfs \
	        bash <post-rootfs.bash

.PHONY: image-overlay
image-overlay: | disk.img mnt
	sudo -E bash image-mount.bash disk.img mnt \
	        rsync -av overlay/. mnt/.

.PHONY: overlay
overlay: | rootfs.tar rootfs
	sudo -E rsync -av overlay/. rootfs/.

.PHONY: mrproper
mrproper: clean
	rm -f .config mirrorlist pacman.conf.in

.PHONY: clean
clean:
	rm -f disk.sfdisk disk.img{,.bmap} rootfs.tar pacman.conf
	sudo -E rm -Rf rootfs

.PRECIOUS: mirrorlist
mirrorlist:
	wget "https://archlinux.org/mirrorlist/?country=all&protocol=http&protocol=https&ip_version=4" --output-document $@.tmp
	sed -e '/## Worldwide/,/^$$/s,^#,,' -i $@.tmp
	mv $@.tmp $@

.PRECIOUS: pacman.conf.in
pacman.conf.in:
	wget https://git.archlinux.org/pacman.git/plain/etc/pacman.conf.in

.PRECIOUS: pacman.conf
pacman.conf: pacman.conf.in | mirrorlist
	sed -e 's,@ROOTDIR@,/,' \
	    -e 's,@sysconfdir@,/etc,' \
	    -e 's,@localstatedir@,/var,' \
		<$< >$@.tmp
	if grep -q '@[[:alnum:]_]\+@' $@.tmp; then \
		echo "Error: Remaining substitutions!" >&2; \
		exit 1; \
	fi
	@for repo in core extra community; do \
		echo >>$@.tmp; \
		echo "[$$repo]" >>$@.tmp; \
		echo "SigLevel = Optional TrustAll" >>$@.tmp; \
		echo "Include = mirrorlist" >>$@.tmp; \
	done
	mv $@.tmp $@

disk.sfdisk: CPPFLAGS += -DROOT_PARTITION_NAME="$(call qstrip,$(CONFIG_ROOT_PARTITION_NAME))"
disk.sfdisk: CPPFLAGS += -DROOT_PARTITION_SIZE="$(call qstrip,$(CONFIG_ROOT_PARTITION_SIZE))"
ifeq ($(CONFIG_HAVE_ROOT_VERITY_PARTITION),y)
disk.sfdisk: CPPFLAGS += -DROOT_VERITY_PARTITION_NAME="$(call qstrip,$(CONFIG_ROOT_VERITY_PARTITION_NAME))"
disk.sfdisk: CPPFLAGS += -DROOT_VERITY_PARTITION_SIZE="$(call qstrip,$(CONFIG_ROOT_VERITY_PARTITION_SIZE))"
endif
disk.sfdisk: CPPFLAGS += -DEFI_SYSTEM_PARTITION_NAME="$(call qstrip,$(CONFIG_EFI_SYSTEM_PARTITION_NAME))"
disk.sfdisk: CPPFLAGS += -DEFI_SYSTEM_PARTITION_SIZE="$(call qstrip,$(CONFIG_EFI_SYSTEM_PARTITION_SIZE))"
disk.sfdisk: CPPFLAGS += -DEXTENDED_BOOT_LOADER_PARTITION_NAME="$(call qstrip,$(CONFIG_EXTENDED_BOOT_LOADER_PARTITION_NAME))"
disk.sfdisk: CPPFLAGS += -DEXTENDED_BOOT_LOADER_PARTITION_SIZE="$(call qstrip,$(CONFIG_EXTENDED_BOOT_LOADER_PARTITION_SIZE))"
ifeq ($(CONFIG_HAVE_VARIABLE_DATA_PARTITION),y)
disk.sfdisk: CPPFLAGS += -DVARIABLE_DATA_PARTITION_NAME="$(call qstrip,$(CONFIG_VARIABLE_DATA_PARTITION_NAME))"
disk.sfdisk: CPPFLAGS += -DVARIABLE_DATA_PARTITION_SIZE="$(call qstrip,$(CONFIG_VARIABLE_DATA_PARTITION_SIZE))"
endif
ifeq ($(CONFIG_HAVE_USR_PARTITION),y)
disk.sfdisk: CPPFLAGS += -DUSR_PARTITION_NAME="$(call qstrip,$(CONFIG_USR_PARTITION_NAME))"
disk.sfdisk: CPPFLAGS += -DUSR_PARTITION_SIZE="$(call qstrip,$(CONFIG_USR_PARTITION_SIZE))"
endif
ifeq ($(CONFIG_HAVE_USR_VERITY_PARTITION),y)
disk.sfdisk: CPPFLAGS += -DUSR_VERITY_PARTITION_NAME="$(call qstrip,$(CONFIG_USR_VERITY_PARTITION_NAME))"
disk.sfdisk: CPPFLAGS += -DUSR_VERITY_PARTITION_SIZE="$(call qstrip,$(CONFIG_USR_VERITY_PARTITION_SIZE))"
endif
ifeq ($(CONFIG_HAVE_SERVER_DATA_PARTITION),y)
disk.sfdisk: CPPFLAGS += -DSERVER_DATA_PARTITION_NAME="$(call qstrip,$(CONFIG_SERVER_DATA_PARTITION_NAME))"
disk.sfdisk: CPPFLAGS += -DSERVER_DATA_PARTITION_SIZE="$(call qstrip,$(CONFIG_SERVER_DATA_PARTITION_SIZE))"
endif
ifeq ($(CONFIG_HAVE_TEMPORARY_DATA_PARTITION),y)
disk.sfdisk: CPPFLAGS += -DTEMPORARY_DATA_PARTITION_NAME="$(call qstrip,$(CONFIG_TEMPORARY_DATA_PARTITION_NAME))"
disk.sfdisk: CPPFLAGS += -DTEMPORARY_DATA_PARTITION_SIZE="$(call qstrip,$(CONFIG_TEMPORARY_DATA_PARTITION_SIZE))"
endif
ifeq ($(CONFIG_HAVE_OTHER_DATA_PARTITION),y)
disk.sfdisk: CPPFLAGS += -DOTHER_DATA_PARTITION_NAME="$(call qstrip,$(CONFIG_OTHER_DATA_PARTITION_NAME))"
disk.sfdisk: CPPFLAGS += -DOTHER_DATA_PARTITION_SIZE="$(call qstrip,$(CONFIG_OTHER_DATA_PARTITION_SIZE))"
endif
ifeq ($(CONFIG_HAVE_SWAP_PARTITION),y)
disk.sfdisk: CPPFLAGS += -DSWAP_PARTITION_NAME="$(call qstrip,$(CONFIG_SWAP_PARTITION_NAME))"
disk.sfdisk: CPPFLAGS += -DSWAP_PARTITION_SIZE="$(call qstrip,$(CONFIG_SWAP_PARTITION_SIZE))"
endif
ifeq ($(CONFIG_HAVE_HOME_PARTITION),y)
disk.sfdisk: CPPFLAGS += -DHAVE_HOME_PARTITION="$(call qstrip,$(CONFIG_HAVE_HOME_PARTITION))"
disk.sfdisk: CPPFLAGS += -DHOME_PARTITION_NAME="$(call qstrip,$(CONFIG_HOME_PARTITION_NAME))"
disk.sfdisk: CPPFLAGS += -DHOME_PARTITION_SIZE="$(call qstrip,$(CONFIG_HOME_PARTITION_SIZE))"
endif
disk.sfdisk: .config

CPP = cpp -P
PREPROCESS.p = $(CPP) $(CPPFLAGS)
OUTPUT_OPTION = -o $@

.PRECIOUS: disk.sfdisk
disk.sfdisk:
%: %.p
	$(PREPROCESS.p) $(OUTPUT_OPTION) $<

.PRECIOUS: disk.img.bmap
disk.img.bmap:
%.bmap: %
	bmaptool create $^ >$@

.INTERMEDIATE: .meta/image.bmap
.meta/image.bmap: disk.img.bmap | .meta
	cp $< $@

disk.img.zip: .meta/image.bmap

.PRECIOUS: %.zip
%.zip:
	pigz --zip $*
	zip $@ $<
