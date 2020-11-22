#!/bin/bash
# Remove dpkg diversions for files which do not exist
# Created by MichaIng / micha@dietpi.com / dietpi.com
{
i=0
while read -r line
do
	# shellcheck disable=SC2015
	(( $i == 3 )) && i=1 || ((i++))
	(( $i == 1 )) || continue
	[[ -e $line ]] || dpkg-divert --remove --no-rename "$line"

done < /var/lib/dpkg/diversions
}
