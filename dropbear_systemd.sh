#!/bin/dash
# Create Dropbear systemd unit with Ed25519 host key
# Created by MichaIng / micha@dietpi.com / dietpi.com
{
sed -e
# Move from wrapper to binary package
apt-get update
apt-get -y --no-install-recommends install dropbear-bin
! dpkg-query -s dropbear > /dev/null 2>&1 || apt-get -y autopurge dropbear

# Remove obsolete files
rm -Rfv /etc/dropbear /etc/default/dropbear

# Create Ed25519 host key
mkdir /etc/dropbear
dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key

# Create systemd unit
cat << '_EOF_' > /etc/systemd/system/dropbear.service
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
systemctl daemon-reload
systemctl disable dropbear || : # Remove obsolete symlinks
update-rc.d dropbear remove || : # Remove /etc/init.d symlinks
systemctl enable dropbear
systemctl restart dropbear
}
