#!/bin/bash
. /boot/dietpi/func/dietpi-globals

# Purge locales and console tools
G_AGP locales console-setup
G_EXEC eval 'echo '\''LANG=C.UTF-8'\'' > /etc/default/locale'
G_EXEC_NOHALT=1 G_EXEC rm -R /usr/share/locale
G_EXEC_NOHALT=1 G_EXEC rm /etc/locale.alias

# Replace p7zip with 7zip
G_AGI 7zip
G_AGP p7zip
G_EXEC ln -s /usr/bin/7zz /usr/local/bin/7zr

# Cleanup dpkg diversions
bash -c "$(curl -sSf 'https://raw.githubusercontent.com/MichaIng/hacks/main/clean_dpkg_diversions.bash')"

# Remove contrib and non-free APT components
G_EXEC eval 'echo '\''deb https://deb.debian.org/debian/ bookworm main'\'' > /etc/apt/sources.list'

# Configure bash
G_EXEC curl -sSf 'https://raw.githubusercontent.com/MichaIng/hacks/main/rootfs/etc/bashrc.d/micha.sh' -o /etc/bashrc.d/micha.sh

# Configure Dropbear
bash -c "$(curl -sSf 'https://raw.githubusercontent.com/MichaIng/hacks/main/dropbear_systemd.sh')"

# Configure GNU/Screen
bash -c "$(curl -sSf 'https://raw.githubusercontent.com/MichaIng/hacks/main/screen_ssh_sessions.sh')"

# Install SFTP server
G_AGI gesftpserver
#G_EXEC ln -s /usr/libexec/gesftpserver /usr/lib/openssh/sftp-server

# Configure Apache2
G_EXEC_NOHALT=1 G_EXEC a2disconf security other-vhosts-access-log charset localized-error-pages serve-cgi-bin
G_EXEC_NOHALT=1 G_EXEC a2dismod -f access_compat auth_basic authn_core authn_file authz_host authz_user autoindex filter info negotiation reqtimeout status deflate filter
G_EXEC a2enmod rewrite headers dir env mime alias authz_core ssl

G_EXEC curl -sSf 'https://raw.githubusercontent.com/MichaIng/hacks/main/rootfs/etc/apache2/conf-available/micha.conf.rpi2' -o /etc/apache2/conf-available/micha.conf
G_EXEC a2enconf micha
