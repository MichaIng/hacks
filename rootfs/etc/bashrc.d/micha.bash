# Add timestamps to shell command prompts
PS1='\D{%F %T} ${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '

# Colorize "ls" command
eval "$(dircolors)"
alias ls='ls -A --color=auto'
alias l='ls -lh'
alias ll='l -L'

# Quick APT upgrade alias
alias APT='apt update && apt list --upgradeable && apt full-upgrade'

# Prevent accidental removals and make them verbose
alias rm='rm -RiIv'
alias mv='mv -iv'
alias cp='cp -iv'
