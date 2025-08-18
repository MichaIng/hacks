#!/bin/bash
{
. /boot/dietpi/func/dietpi-globals

# Inputs:
# - "-e": drop to shell for edit
# - "-b": has boot partition: if set, assumes partition 1 to be boot partition, and partition 2 to be rootfs
# - $1: img path
# - $2: img size (GiB, optional, defaults to 2)
EDIT=0
FP_IMG=
FS_IMG=
ROOT_PART=1
BOOT_PART=
while (( $# ))
do
	case $1 in
		'-e') EDIT=1;;
		'-b') BOOT_PART=1 ROOT_PART=2;;
		*) [[ $FP_IMG ]] && FS_IMG=$1 || FP_IMG=$1;;
	esac
	shift
done
G_EXEC test -f "$FP_IMG"
disable_error=1 G_CHECK_VALIDINT "$FS_IMG" 0 || FS_IMG=2

# Install QEMU emulation support when running from x86_64 host
(( $G_HW_ARCH == 10 )) && emulation_packages=('qemu-user-static') || emulation_packages=()
G_AG_CHECK_INSTALL_PREREQ parted fdisk dbus systemd-container "${emulation_packages[@]}"
[[ ${emulation_packages[0]} ]] && G_EXEC systemctl restart systemd-binfmt
LOOP_DEV=$(losetup -f)
ROOT_DEV="${LOOP_DEV}p$ROOT_PART"
[[ $BOOT_PART ]] && BOOT_DEV="${LOOP_DEV}p$BOOT_PART" && G_AG_CHECK_INSTALL_PREREQ dosfstools

G_EXIT_CUSTOM()
{
	# Revert workarounds
	G_EXEC rm -f rootfs/etc/systemd/system/dropbear.service
	for i in rootfs/etc/systemd/system/*.service.d/no-credentials.conf
	do
		[[ $i == 'rootfs/etc/systemd/system/*.service.d/no-credentials.conf' ]] && break
		G_EXEC rm "$i"
		G_EXEC rmdir --ignore-fail-on-non-empty "${i%/no-credentials.conf}"
	done
	# Cleanup
	findmnt -M rootfs > /dev/null && G_EXEC umount -Rl rootfs
	G_EXEC losetup -d "$LOOP_DEV"
	[[ -d 'rootfs' ]] && G_EXEC rmdir rootfs
}
trap G_EXIT_CUSTOM EXIT

# Create loop device and fsck
G_EXEC losetup -P "$LOOP_DEV" "$FP_IMG"
G_EXEC_OUTPUT=1 G_EXEC e2fsck -fyD "$ROOT_DEV"
[[ $BOOT_DEV ]] && G_EXEC_OUTPUT=1 G_EXEC fsck -y "$BOOT_DEV"

# Raise image+partition+fs size if required, always run fsck
if (( $FS_IMG && $(stat -c '%s' "$FP_IMG") < $FS_IMG*1024**3 ))
then
	G_EXEC truncate -s $(($FS_IMG*1024**3)) "$FP_IMG"
	G_EXEC losetup -c "$LOOP_DEV"
	if [[ $(blkid -s PTTYPE -o value -c /dev/null "$LOOP_DEV") == 'gpt' ]]
	then
		G_AG_CHECK_INSTALL_PREREQ gdisk
		G_EXEC sgdisk -e "$LOOP_DEV"
	fi
	G_EXEC_OUTPUT=1 G_EXEC eval "sfdisk -fN'${ROOT_DEV: -1}' '$LOOP_DEV' <<< ',+'"
	G_EXEC partprobe "$LOOP_DEV"
	G_EXEC partx -u "$LOOP_DEV"
	G_EXEC_OUTPUT=1 G_EXEC resize2fs "$ROOT_DEV"
fi

# Mount
G_EXEC mkdir -p rootfs
findmnt -M rootfs &> /dev/null && G_EXEC umount -R rootfs
G_EXEC mount "$ROOT_DEV" rootfs
[[ $BOOT_DEV ]] && G_EXEC mount "$BOOT_DEV" rootfs/boot

# Drop to shell for edit
(( $EDIT )) && bash

# Workarounds
# - Mask Dropbear to prevent its package install from failing
ln -s /dev/null rootfs/etc/systemd/system/dropbear.service
# - Prevent failing services and missing login prompt by disabling credentials in systemd units
if [[ ${emulation_packages[0]} ]]
then
	for i in rootfs/lib/systemd/system/*.service
	do
		[[ -f $i ]] || continue
		grep -q '^ImportCredential=' "$i" && G_EXEC mkdir -p "${i/lib/etc}.d" && G_EXEC eval "echo -e '[Service]\nImportCredential=' > '${i/lib/etc}.d/no-credentials.conf'"
		grep -q '^LoadCredential=' "$i" && G_EXEC mkdir -p "${i/lib/etc}.d" && G_EXEC eval "echo -e '[Service]\nLoadCredential=' > '${i/lib/etc}.d/no-credentials.conf'"
	done
fi

# dbus required for container spawn
G_EXEC systemctl unmask dbus.socket dbus
G_EXEC systemctl start dbus.socket dbus
# Bind mounts required to allow container reading its own mount info
systemd-nspawn -bD rootfs --bind="$LOOP_DEV" --bind="$ROOT_DEV" ${BOOT_DEV:+--bind="$BOOT_DEV"} --bind=/dev/disk

exit 0
}
