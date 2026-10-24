#!/bin/dash -e
# https://decatec.de/home-server/nextcloud-talk-mit-eigenem-signaling-server-high-performance-backend/
# https://najigram.com/2024/01/setup-signaling-server-high-performance-backend-for-nextcloud-talk/
# https://docs.nats.io/concepts/getting-started/#install-nats-server => https://github.com/nats-io/nats-server/releases

dietpi-software install git go
. /etc/bashrc.d/go.sh
apt install make

### Signaling ###

# Install
cd /mnt/dietpi_userdata
git clone 'https://github.com/strukturag/nextcloud-spreed-signaling' signaling
cd signaling
make build

# User
useradd -rMN -d /mnt/dietpi_userdata/signaling -s /usr/sbin/nologin signaling

# Config
cp server.conf.in server.conf
chmod 0600 server.conf
chown signaling:0 server.conf

port=$(od -An -N5 -tu1 /dev/urandom | mawk '{printf "%d", 1+($1 % 5); for (i=2; i<=5; i++) printf "%d", $i % 10}')
sed --follow-symlinks -i '/^[[:blank:]#]*certificate[[:blank:]=]/c\certificate = /mnt/dietpi_userdata/signaling/fullchain.pem' server.conf
sed --follow-symlinks -i '/^[[:blank:]#]*key[[:blank:]=]/c\key = /mnt/dietpi_userdata/signaling/privkey.pem' server.conf
sed --follow-symlinks -i "/^\[https\]/,/^\[.*\]/s/^[[:blank:]#]*listen[[:blank:]=].*\$/listen = 0.0.0.0:$port/" server.conf

hashkey=$(openssl rand -hex 16)
blockkey=$(openssl rand -hex 16)
secret=$(openssl rand -hex 16)
sed --follow-symlinks -i "/^[[:blank:]#]*hashkey[[:blank:]=]/c\hashkey = $hashkey" server.conf
sed --follow-symlinks -i "/^[[:blank:]#]*blockkey[[:blank:]=]/c\blockkey = $blockkey" server.conf
sed --follow-symlinks -i "/^[[:blank:]#]*internalsecret[[:blank:]=]/c\internalsecret = $secret" server.conf

domain=$(sed -n '/^[[:blank:]]*SOFTWARE_PUBLIC_DOMAIN_NAME=/{s/^[^=]*=//p;q}' /boot/dietpi.txt)
secret=$(openssl rand -hex 16)
sed --follow-symlinks -i '/^#*backends[[:blank:]=]/c\backends = backend-id' server.conf
sed --follow-symlinks -i '/^#*\[backend-id\]/c\[backend-id]' server.conf
sed --follow-symlinks -i "/^\[backend-id\]/,/^#*\[.*\]/s|^[[:blank:]#]*urls[[:blank:]=].*\$|urls = https://$domain/nextcloud|" server.conf
sed --follow-symlinks -i "/^\[backend-id\]/,/^#*\[.*\]/s/^[[:blank:]#]*secret[[:blank:]=].*\$/secret = $secret/" server.conf

sed --follow-symlinks -i '/^\[mcu\]/,/^#*\[.*\]/s/^[[:blank:]#]*type[[:blank:]=].*$/type = janus/' server.conf
sed --follow-symlinks -i '/^\[mcu\]/,/^#*\[.*\]/s|^[[:blank:]#]*url[[:blank:]=].*$|url = ws://127.0.0.1:8188|' server.conf

apikey=$(openssl rand -base64 16)
secret=$(sed -n '/^[[:blank:]]*static-auth-secret=/{s/^[^=]*=//p;q}' /etc/turnserver.conf)
port=$(sed -n '/^[[:blank:]]*listening-port=/{s/^[^=]*=//p;q}' /etc/turnserver.conf)
sed --follow-symlinks -i "/^\[turn\]/,/^#*\[.*\]/s|^[[:blank:]#]*apikey[[:blank:]=].*\$|apikey = $apikey|" server.conf
sed --follow-symlinks -i "/^\[turn\]/,/^#*\[.*\]/s/^[[:blank:]#]*secret[[:blank:]=].*\$/secret = $secret/" server.conf
sed --follow-symlinks -i "/^\[turn\]/,/^#*\[.*\]/s/^[[:blank:]#]*servers[[:blank:]=].*\$/servers = turn:127.0.0.1:$port?transport=udp,turn:127.0.0.1:$port?transport=tcp/" server.conf

# Certbot hook
cat << _EOF_ > /etc/letsencrypt/renewal-hooks/deploy/signaling.sh || exit 1
#!/bin/dash -e
# Ensure strict permissions while copying:
umask 377

# Copy to Nextcloud Talk Signaling server dir
cp /etc/letsencrypt/live/*/fullchain.pem /mnt/dietpi_userdata/signaling/
cp /etc/letsencrypt/live/*/privkey.pem /mnt/dietpi_userdata/signaling/

# Re-Own those certs!
chown signaling:0 /mnt/dietpi_userdata/signaling/fullchain.pem /mnt/dietpi_userdata/signaling/privkey.pem

# Restart Nextcloud Talk Signaling server to use new cert
systemctl restart signaling
_EOF_
chmod +x /etc/letsencrypt/renewal-hooks/deploy/signaling.sh

# Service: https://github.com/strukturag/nextcloud-spreed-signaling/blob/master/dist/init/systemd/signaling.service
cat << '_EOF_' > /etc/systemd/system/signaling.service  || exit 1
[Unit]
Description=Nextcloud Talk Signaling server
Wants=network-online.target
After=network-online.target
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
User=signaling
ExecStart=/mnt/dietpi_userdata/signaling/bin/signaling --config /mnt/dietpi_userdata/signaling/server.conf
Restart=on-failure

# Hardening
CapabilityBoundingSet=
ExecPaths=/mnt/dietpi_userdata/signaling/bin/signaling /usr/lib
LockPersonality=yes
MemoryDenyWriteExecute=yes
NoExecPaths=/
NoNewPrivileges=yes
PrivateDevices=yes
PrivateTmp=yes
PrivateUsers=yes
ProcSubset=pid
ProtectClock=yes
ProtectControlGroups=yes
ProtectHome=yes
ProtectHostname=yes
ProtectKernelLogs=yes
ProtectKernelModules=yes
ProtectKernelTunables=yes
ProtectProc=invisible
ProtectSystem=strict
RemoveIPC=yes
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
RestrictNamespaces=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes
SystemCallArchitectures=native
SystemCallFilter=@system-service
SystemCallFilter=~@privileged

[Install]
WantedBy=multi-user.target
_EOF_

### Janus ###

# Install
apt install janus

# Config
sed --follow-symlinks -i '/^[[:blank:]#]*stun_server[[:blank:]]/c\\tstun_server = "127.0.0.1"' /etc/janus/janus.jcfg
sed --follow-symlinks -i "/^[[:blank:]#]*stun_port[[:blank:]]/c\\\tstun_port = $port" /etc/janus/janus.jcfg
sed --follow-symlinks -i '/^[[:blank:]#]*full_trickle[[:blank:]]/c\\tfull_trickle = true' /etc/janus/janus.jcfg
sed --follow-symlinks -i "/^[[:blank:]#]*turn_rest_api_key[[:blank:]]/c\\\tturn_rest_api_key = \"$apikey\"" /etc/janus/janus.jcfg

sed --follow-symlinks -i '/^[[:blank:]#]*interface[[:blank:]]/c\\tinterface = "lo"' /etc/janus/janus.transport.http.jcfg
sed --follow-symlinks -i '/^[[:blank:]#]*ws_interface[[:blank:]]/c\\tws_interface = "lo"' /etc/janus/janus.transport.websockets.jcfg

### NATS ###

# Install
case $G_HW_ARCH in
	1) arch='arm6';;
	2) arch='arm7';;
	3) arch='arm64';;
	11) arch='riscv64';;
	*) arch='amd64';;
esac
url=$(curl -sSfL 'https://api.github.com/repos/nats-io/nats-server/releases/latest' | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/nats-server-v[0-9.]*-linux-$arch\.tar\.gz(?=\")")
[[ $url ]]
cd /tmp
curl -fLo nats.tar.gz "$url"
tar xf nats.tar.gz --wildcards --strip-components=1 --no-same-owner '*/nats-server'
rm nats.tar.gz
mkdir -p /opt/nats
mv nats-server /opt/nats
chmod +x /opt/nats/nats-server

# User
useradd -rMN -d /mnt/dietpi_userdata/nats -s /usr/sbin/nologin nats

# Config/data dir
mkdir -p /mnt/dietpi_userdata/nats
chown nats: /mnt/dietpi_userdata/nats

# Config
port=$(od -An -N5 -tu1 /dev/urandom | mawk '{printf "%d", 1+($1 % 5); for (i=2; i<=5; i++) printf "%d", $i % 10}')
cat << _EOF_ > /mnt/dietpi_userdata/nats/nats.conf || exit 1
# /mnt/dietpi_userdata/nats/nats.conf
host: 127.0.0.1
port: $port
#tls {
#    cert_file: "/mnt/dietpi_userdata/nats/fullchain.pem"
#    key_file:  "/mnt/dietpi_userdata/nats/privkey.pem"
#}
_EOF_
sed --follow-symlinks -i "/^\[nats\]/,/^\[.*\]/s|^[[:blank:]#]*url[[:blank:]=].*\$|url = nats://127.0.0.1:$port|" server.conf

# Certbot hook
# cat << _EOF_ > /etc/letsencrypt/renewal-hooks/deploy/nats.sh || exit 1
# #!/bin/dash -e
# # Ensure strict permissions while copying:
# umask 377

# # Copy to NATS config dir
# cp /etc/letsencrypt/live/*/fullchain.pem /mnt/dietpi_userdata/nats/
# cp /etc/letsencrypt/live/*/privkey.pem /mnt/dietpi_userdata/nats/

# # Re-Own those certs!
# chown nats:0 /mnt/dietpi_userdata/nats/fullchain.pem /mnt/dietpi_userdata/nats/privkey.pem

# # Restart Nextcloud Talk Signaling server to use new cert
# systemctl restart nats
# _EOF_
# chmod +x /etc/letsencrypt/renewal-hooks/deploy/nats.sh

# Service: https://docs.nats.io/learn/deployment/hardening#a-hardened-systemd-unit
cat << '_EOF_' > /etc/systemd/system/nats.service || exit 1
# /etc/systemd/system/nats.service
[Unit]
Description=NATS server
Wants=network-online.target
After=network-online.target

[Service]
User=nats
ExecStart=/opt/nats/nats-server -c /mnt/dietpi_userdata/nats/nats.conf
ExecReload=/bin/kill -s HUP $MAINPID

# 2 file descriptors per stream plus gossip and client sockets.
# A large cluster exhausts the default 1024 quickly.
#LimitNOFILE=8192

# Hardening
ProtectSystem=strict
ReadWritePaths=/mnt/dietpi_userdata/nats
MemoryDenyWriteExecute=true
ProtectKernelTunables=true
ProtectProc=invisible
PrivateDevices=true
CapabilityBoundingSet=
SystemCallFilter=@system-service
SystemCallFilter=~@privileged @resources

[Install]
WantedBy=multi-user.target
_EOF_
