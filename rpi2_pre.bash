#!/bin/bash
. /boot/dietpi/func/dietpi-globals

# Disable local console logging and cursor
for i in 'quiet' 'loglevel=0' 'vt.global_cursor_default=0'
do
	grep "[[:blank:]]$i" /boot/cmdline.txt || G_EXEC sed "1s/\$/ $i/" /boot/cmdline.txt
done

# Deploy config.txt
[[ -f '/boot/config.txt.rpi2' ]] && G_EXEC mv /boot/config.txt{.rpi2,}

# Deploy DPKG config
[[ -f '/boot/dpkg.cfg.rpi2' ]] && G_EXEC mv /boot/dpkg.cfg.rpi2 /etc/dpkg/dpkg.cfg.d/01-micha

# Purge non-required important/required/essential packages
G_AGP --allow-remove-essential init install-info liblocale-gettext-perl libtext-charwidth-perl libtext-iconv-perl libtext-wrapi18n-perl base-passwd

# Remove non-required files
G_EXEC_NOHALT=1 G_EXEC rm /etc/cron.d/e2scrub_all
G_EXEC_NOHALT=1 G_EXEC rm /etc/cron.daily/apt-compat
G_EXEC_NOHALT=1 G_EXEC rm /etc/cron.daily/dpkg
G_EXEC_NOHALT=1 G_EXEC rm -R /etc/{rc?.d,init{,.d}}
G_EXEC_NOHALT=1 G_EXEC rm -R /etc/insserv.conf.d
G_EXEC_NOHALT=1 G_EXEC rm -R /etc/sv
G_EXEC_NOHALT=1 G_EXEC rm -R /etc/runit
G_EXEC_NOHALT=1 G_EXEC rm -R /etc/X11
G_EXEC_NOHALT=1 G_EXEC rm -R /usr/share/X11
G_EXEC_NOHALT=1 G_EXEC rm -R /etc/dhcp
G_EXEC_NOHALT=1 G_EXEC rm -R /etc/ufw
G_EXEC_NOHALT=1 G_EXEC rm -R /var/lib/polkit-1
G_EXEC_NOHALT=1 G_EXEC rm /etc/update-motd.d/10-uname
G_EXEC_NOHALT=1 G_EXEC rm -R /etc/skel/*
G_EXEC_NOHALT=1 G_EXEC rm /etc/issue*
G_EXEC_NOHALT=1 G_EXEC rm /etc/apt/apt.conf.d/01autoremove*
G_EXEC_NOHALT=1 G_EXEC rm /etc/kernel/postinst.d/apt-auto-removal
G_EXEC_NOHALT=1 G_EXEC rm /etc/apt/apt.conf.d/70debconf
G_EXEC_NOHALT=1 G_EXEC rm /etc/default/fake-hwclock
G_EXEC_NOHALT=1 G_EXEC rm /etc/ld.so.conf.d/00-vmcs.conf

# Make shell autocompletion case-insensitive
G_CONFIG_INJECT 'set[[:blank:]]+completion-ignore-case[[:blank:]]' 'set completion-ignore-case on' /etc/inputrc
