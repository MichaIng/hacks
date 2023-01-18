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

# Disable TTY1 console
G_EXEC systemctl disable --now getty@tty1

# Install SFTP server
G_AGI gesftpserver
#G_EXEC ln -s /usr/libexec/gesftpserver /usr/lib/openssh/sftp-server

# Configure Redis
G_CONFIG_INJECT 'bind[[:blank:]]' 'bind ""' /etc/redis/redis.conf
G_CONFIG_INJECT 'port[[:blank:]]' 'port 0' /etc/redis/redis.conf
G_CONFIG_INJECT 'tcp-backlog[[:blank:]]' 'tcp-backlog 128' /etc/redis/redis.conf
G_CONFIG_INJECT 'databases[[:blank:]]' 'databases 1' /etc/redis/redis.conf
G_CONFIG_INJECT 'acllog-max-len[[:blank:]]' 'acllog-max-len 32' /etc/redis/redis.conf
G_CONFIG_INJECT 'bind[[:blank:]]' 'bind ""' /etc/redis/redis.conf
G_CONFIG_INJECT 'maxmemory[[:blank:]]' 'maxmemory 16mb' /etc/redis/redis.conf
G_CONFIG_INJECT 'slowlog-max-len[[:blank:]]' 'slowlog-max-len 32' /etc/redis/redis.conf

# Configure PHP-FPM
G_EXEC sed -i 's/^pid/;pid/' /etc/php/*/fpm/php-fpm.conf
G_CONFIG_INJECT 'error_log[[:blank:]=]' 'error_log = syslog' /etc/php/*/fpm/php-fpm.conf

# Configure PHP
G_EXEC phpenmod apcu ctype curl dom exif fileinfo gd igbinary intl mbstring mysqlnd opcache pdo pdo_mysql posix redis simplexml xml xmlreader xmlwriter zip
G_EXEC phpdismod calendar ffi ftp gettext iconv mysqli phar readline shmop sockets sysvmsg sysvsem sysvshm tokenizer xsl

# Configure Apache2
G_EXEC_NOHALT=1 G_EXEC a2disconf security other-vhosts-access-log charset localized-error-pages serve-cgi-bin
G_EXEC_NOHALT=1 G_EXEC a2dismod -f access_compat auth_basic authn_core authn_file authz_host authz_user autoindex filter info negotiation reqtimeout status deflate filter
G_EXEC a2enmod rewrite headers dir env mime alias authz_core ssl

G_EXEC curl -sSf 'https://raw.githubusercontent.com/MichaIng/hacks/main/rootfs/etc/apache2/conf-available/micha.conf.rpi2' -o /etc/apache2/conf-available/micha.conf
G_EXEC a2enconf micha

# Setup acme.sh
bash -c "$(curl -sSf 'https://raw.githubusercontent.com/MichaIng/hacks/main/setup_acme.sh')"

# Configure Coturn
G_EXEC sed -i 's/^[[:blank:]]*listening-port=/#listening-port=/' /etc/turnserver.conf
G_CONFIG_INJECT 'alt-listening-port=' 'alt-listening-port=3478' /etc/turnserver.conf
G_CONFIG_INJECT 'relay-threads=' 'relay-threads=0' /etc/turnserver.conf
#G_EXEC sed -i 's/^[[:blank:]]*bps-capacity=/#bps-capacity=/' /etc/turnserver.conf
G_CONFIG_INJECT 'no-tls' 'no-tls' /etc/turnserver.conf
G_CONFIG_INJECT 'no-dtls' 'no-dtls' /etc/turnserver.conf
#G_EXEC sed -i 's/^[[:blank:]]*syslog/#syslog/' /etc/turnserver.conf
G_CONFIG_INJECT 'no-cli' 'no-cli' /etc/turnserver.conf