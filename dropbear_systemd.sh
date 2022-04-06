#!/bin/dash
# Create Dropbear systemd unit with Ed25519 host key
# Created by MichaIng / micha@dietpi.com / dietpi.com
{
# Remove obsolete SysV and upstart files
dpkg-query -s dropbear-run > /dev/null 2>&1 && { apt-get -qq purge dropbear-run || exit 1; }
dpkg-query -s dropbear > /dev/null 2>&1 && { apt-get -qq purge dropbear || exit 1; }

# Assure up-to-date Dropbear binary is installed
apt-get -q update || exit 1
apt-get -qq install --no-install-recommends dropbear-bin || exit 1

# Remove obsolete files
[ -d '/etc/dropbear' ] && { rm -Rv /etc/dropbear || exit 1; }
[ -f '/etc/default/dropbear' ] && { rm -v /etc/default/dropbear || exit 1; }

# Create Ed25519 host key
mkdir -p /etc/dropbear || exit 1
grep -q bullseye /etc/os-release && type='ed25519' size= || type='ecdsa' size=521
dropbearkey -t $type -f /etc/dropbear/dropbear_${type}_host_key ${size:+-s $size} || exit 1

# Create systemd unit
cat << _EOF_ > /etc/systemd/system/dropbear.service || exit 1
[Unit]
Description=Dropbear
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/sbin/dropbear -EFsr '/etc/dropbear/dropbear_${type}_host_key' -P ''
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
