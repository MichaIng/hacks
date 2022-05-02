#!/bin/dash
# Install and setup GNU Screen for SSH sessions
# Created by MichaIng / micha@dietpi.com / dietpi.com
{
# Install Screen
apt-get -y update
apt-get -y --no-install-recommends install screen

# Disable startup message
sed -i '/^[[:blank:]#]*startup_message/c\#startup_message off' /etc/screenrc

# Disable hardstatus line
sed -i 's/^[[:blank:]]*hardstatus[[:blank:]]/#hardstatus /' /etc/screenrc
sed -i 's/^[[:blank:]]*termcapinfo xterm\*|rxvt\*|kterm\*|Eterm\*/#termcapinfo xterm*|rxvt*|kterm*|Eterm*/' /etc/screenrc
sed -Ei '/^#hardstatus[[:blank:]]+(on|off)/c\hardstatus off' /etc/screenrc

# Enable scollback buffer
sed -i '/^[[:blank:]#]*termcapinfo xterm|xterms|xs|rxvt ti@:te@$/c\termcapinfo xterm|xterms|xs|rxvt ti@:te@' /etc/screenrc

# Additions
cat << '_EOF_' >> /etc/screenrc
# ------------------------------------------------------------------------------
# MICHA'S ADDITIONS
# ------------------------------------------------------------------------------

# Use bash shell
shell /bin/bash

# Remove whiptail/pager content after closing
altscreen on

# Add information status line to screen windows
caption always "%{Gk}%-w%{kG}%n %t%{-}%+w"
_EOF_

# Automatically start screen on SSH sessions
cat << '_EOF_' > /etc/profile.d/00-micha.sh
# Autostart screen and auto logout on detach
[ "$TERM" = 'screen' ] || exec screen -U -S sshscreen -d -R
_EOF_

# Use dash as default shell to reduce overhead before screen is loaded
usermod -s /bin/dash root
getent passwd dietpi > /dev/null && usermod -s /bin/dash dietpi
}
