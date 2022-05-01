#!/bin/bash
{
. /boot/dietpi/func/dietpi-globals

# Inputs: "-e"=edit dietpi.txt, $1=img file, $2=img size (GiB, optional, defaults to 2)
EDIT_DIETPITXT=0
FP_IMG=
FS_IMG=
while (( $# ))
do
	case $1 in
		'-e') EDIT_DIETPITXT=1;;
		*) [[ $FP_IMG ]] && FS_IMG=$1 || FP_IMG=$1;;
	esac
	shift
done
G_EXEC test -f "$FP_IMG"
disable_error=1 G_CHECK_VALIDINT "$FS_IMG" 0 || FS_IMG=2

# Install QEMU emulation support only when running from non-RPi host, else assume we're going to build for armhf anyway
(( $G_HW_MODEL > 9 )) && emulation_packages=('qemu-user-static' 'binfmt-support') || emulation_packages=()
G_AG_CHECK_INSTALL_PREREQ parted fdisk dosfstools dbus systemd-container "${emulation_packages[@]}"
LOOP_DEV=$(losetup -f)
ROOT_DEV="${LOOP_DEV}p2"

G_EXIT_CUSTOM()
{
	G_EXEC systemctl mask --now dbus dbus.socket

	# Revert workarounds
	(( $remove_pts )) && sed -i '/^pts\/0/d' m/etc/securetty
	G_EXEC rm -f m/etc/{systemd/system/dropbear.service,ld.so.preload_bak} m/var/lib/dietpi/postboot.d/micha-remount_tmp.sh

	# Cleanup
	findmnt -M m > /dev/null && G_EXEC umount -Rl m
	G_EXEC losetup -d "$LOOP_DEV"
	[[ -d 'm' ]] && G_EXEC rmdir m
}
trap G_EXIT_CUSTOM EXIT

# Create loop device and fsck
G_EXEC losetup "$LOOP_DEV" "$FP_IMG"
G_EXEC partprobe "$LOOP_DEV"
G_EXEC partx -u "$LOOP_DEV"
[[ -b ${LOOP_DEV}p2 ]] && BOOT_DEV="${LOOP_DEV}p1" || ROOT_DEV="${LOOP_DEV}p1"
G_EXEC_OUTPUT=1 G_EXEC e2fsck -fp "$ROOT_DEV"
[[ $BOOT_DEV ]] && G_EXEC_OUTPUT=1 G_EXEC fsck -p "$BOOT_DEV"

# Raise image+partition+fs size if required, always run fsck
if (( $FS_IMG && $(stat -c %s "$FP_IMG") < $FS_IMG*1024**3 ))
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
	G_EXEC_OUTPUT=1 G_EXEC e2fsck -fp "$ROOT_DEV"
fi

# Mount
[[ -d 'm' ]] || G_EXEC mkdir m
findmnt -M m &> /dev/null && G_EXEC umount -R m
G_EXEC mount "$ROOT_DEV" m
[[ $BOOT_DEV ]] && G_EXEC mount "$BOOT_DEV" m/boot

# Edit dietpi.txt if requested
(( $EDIT_DIETPITXT )) && nano m/boot/dietpi.txt

# Workarounds
# - Allow root login on pts/0, required until Buster, on Bullseye /etc/securetty has been removed
[[ -f 'm/etc/securetty' ]] && ! grep '^pts/0' m/etc/securetty && echo 'pts/0' >> m/etc/securetty && remove_pts=1
# - Mask Dropbear to prevent its package install from failing
ln -s /dev/null m/etc/systemd/system/dropbear.service
# - Remount /tmp tmpfs as it does not mount with intended size automatically somehow
[[ -d 'm/var/lib/dietpi/postboot.d' ]] && echo -e '#!/bin/dash\nmount -o remount /tmp' > m/var/lib/dietpi/postboot.d/micha-remount_tmp.sh

# dbus required for container spawn
G_EXEC systemctl unmask dbus.socket dbus
G_EXEC systemctl start dbus.socket dbus
# Bind mounts required to allow container reading its own mount info
abinds=()
#abinds+=('--bind=/dev/fb0' '--bind=/dev/dri' '--bind=/dev/tty1')
#abinds+=('--bind=/dev/gpiochip0' '--bind=/dev/gpiomem' '--bind=/sys/class/gpio' '--bind=/sys/devices/platform/soc/3f200000.gpio')
systemd-nspawn -bD m --bind="$LOOP_DEV" --bind="$ROOT_DEV" ${BOOT_DEV:+--bind="$BOOT_DEV"} --bind=/dev/disk "${abinds[@]}"

exit 0
}
