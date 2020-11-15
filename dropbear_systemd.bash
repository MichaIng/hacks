#!/bin/bash
# Create Dropbear systemd unit with Ed25519 host key
# Created by MichaIng / micha@dietpi.com / dietpi.com
{
# Remove obsolete SysV and upstart files
dpkg-query -s dropbear-run &> /dev/null && apt-get -qq purge dropbear-run

# Assure up-to-date Dropbear binary is installed
apt-get -q update
apt-get -qq install --no-install-recommends dropbear-bin

# Remove obsolete files
[[ -d '/etc/dropbear' ]] && rm -Rv /etc/dropbear
[[ -f '/etc/default/dropbear' ]] && rm -v /etc/default/dropbear

# Create Ed25519 host key
mkdir -p /etc/dropbear
grep -q bullseye /etc/os-release && type='ed25519' size= || type='ecdsa' size=521
dropbearkey -t $type -f /etc/dropbear/dropbear_${type}_host_key ${size:+-s $size}

# Create systemd unit
cat << '_EOF_' > /etc/systemd/system/dropbear.service
[Unit]
Description=Dropbear
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/sbin/dropbear -Fsr '/etc/dropbear/dropbear_ed25519_host_key' -P ''

[Install]
WantedBy=multi-user.target
_EOF_

# Start service
systemctl daemon-reload
systemctl restart dropbear
}
