#!/bin/dash
# Install acme.sh and issue a 384-bit ECC certificate + auto renewal cron job
# Input argument $1 = domain
{
mkdir -p /opt/acme.sh || exit 1
cd /opt/acme.sh || exit 1
curl -sSfLO 'https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh' || exit 1
chmod +x acme.sh || exit 1
./acme.sh --issue --home /opt/acme.sh -d "$1" -w /var/www -k 'ec-384' --ocsp --server 'letsencrypt' || exit 1
cat << '_EOF_' > /etc/cron.daily/micha || exit 1
#!/bin/dash
{
	echo "[$(date)] INFO: Updating acme.sh..."
	if curl -sSf 'https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh' -o /opt/acme.sh/acme.sh
	then
		echo "[$(date)] DONE: acme.sh version is: $(sed -n '/^VER=/{s/^VER=//p;q}' /opt/acme.sh/acme.sh)"
		/opt/acme.sh/acme.sh --renew-all --home /opt/acme.sh || echo "[$(date)] ERROR: Failed to renew acme.sh certificate"
	else
		echo "[$(date)] ERROR: Failed to download acme.sh"
	fi
	echo '-------------------------------------------------------------'
	exit 0

} >> /var/log/acme.sh.log 2>&1
{
	echo "[$(date '+%F %T')] Enabling Nextcloud maintenance mode"
	if sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --on
	then
		echo "[$(date '+%F %T')] Creating database dump"
		mysqldump nextcloud > /mnt/sda/ncdata/dbbackup/$(date +%F_%T).sql

		echo "[$(date '+%F %T')] Mounting backup drive"
		if findmnt /mnt/sdb > /dev/null || mount /mnt/sdb
		then
			echo "[$(date '+%F %T')] Backing up Nextcloud data"
			rsync -aH --delete /mnt/sda/ncdata /mnt/sdb/backup/

			echo "[$(date '+%F %T')] Backing up Nextcloud install"
			rsync -aH --delete /var/www/nextcloud /mnt/sdb/backup/

			echo "[$(date '+%F %T')] Backing up Let's Encrypt"
			rsync -aH --delete /opt/acme.sh /mnt/sdb/backup/

			echo "[$(date '+%F %T')] Forcing disk sync"
			sync

			echo "[$(date '+%F %T')] Unmounting backup drive"
			umount /mnt/sdb
		else
			echo "[$(date '+%F %T')] ERROR: Failed to mount backup drive"
		fi

		echo "[$(date '+%F %T')] Disabling Nextcloud maintenance mode"
		sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --off
	else
		echo "[$(date '+%F %T')] ERROR: Failed to enable Nextcloud maintenance mode"
	fi
	echo "[$(date '+%F %T')] Removing old database dumps"
	while [ $(find /mnt/sda/ncdata/dbbackup -name '*.sql' | wc -l) -gt 10 ]
	do
		rm -v "$(find /mnt/sda/ncdata/dbbackup -name '*.sql' | sort -n | head -1)"
	done
	echo '-------------------------------------------------------------'
	exit 0

} >> /var/log/micha-backup.log 2>&1
_EOF_
chmod +x /etc/cron.daily/micha || exit 1
}
