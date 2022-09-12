#!/bin/dash
# Install acme.sh and issue a 384-bit ECC certificate + auto renewal cron job
# Input argument $1 = domain
{
mkdir -p /opt/acme.sh || exit 1
cd /opt/acme.sh || exit 1
curl -sSfLO 'https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh' || exit 1
chmod +x acme.sh || exit 1
./acme.sh --issue --home /opt/acme.sh -d "$1" -w /var/www -k 'ec-384' --ocsp --server 'letsencrypt' || exit 1
cat << '_EOF_' > /etc/cron.daily/micha-acme_sh
#!/bin/dash
{
	# Update acme.sh
	echo "[$(date)] INFO: Updating acme.sh..."
	if curl -sSfL 'https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh' -o /opt/acme.sh/acme.sh
	then
		echo "[$(date)] DONE: acme.sh version is: $(sed -n '/^VER=/{s/^VER=//p;q}' /opt/acme.sh/acme.sh)"
		/opt/acme.sh/acme.sh --renew-all --home /opt/acme.sh || echo "[$(date)] ERROR: Failed to renew acme.sh certificate"
	else
		echo "[$(date)] ERROR: Failed to download acme.sh"
	fi
	echo '-------------------------------------------------------------'
	exit 0
} >> /var/log/acme.sh.log 2>&1
_EOF_
chmod +x /etc/cron.daily/micha-acme_sh || exit 1
}
