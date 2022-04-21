#!/bin/dash
# Create Dropbear systemd unit with Ed25519 host key
# Created by MichaIng / micha@dietpi.com / dietpi.com
{
# Remove obsolete SysV and upstart files
dpkg-query -s dropbear-run > /dev/null 2>&1 && { apt-get -y purge dropbear-run || exit 1; }
dpkg-query -s dropbear > /dev/null 2>&1 && { apt-get -y purge dropbear || exit 1; }

# Assure up-to-date Dropbear binary is installed
apt-get update || exit 1
apt-get -y --no-install-recommends install dropbear-bin || exit 1

# Remove obsolete files
rm -Rfv /etc/dropbear /etc/default/dropbear || exit 1

# Create Ed25519 host key
mkdir /etc/dropbear || exit 1
dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key || exit 1

# Create systemd unit
cat << '_EOF_' > /etc/systemd/system/dropbear.service || exit 1
[Unit]
Description=Dropbear
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/sbin/dropbear -EFsr '/etc/dropbear/dropbear_ed25519_host_key' -P ''
KillMode=process

[Install]
WantedBy=multi-user.target
_EOF_

# Start service
systemctl daemon-reload || exit 1
systemctl disable dropbear # Remove obsolete symlinks
update-rc.d dropbear remove # Remove /etc/init.d symlinks
systemctl enable dropbear || exit 1
systemctl restart dropbear || exit 1
}
