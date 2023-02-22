#!/bin/dash
# Add timestamps to shell command prompts
# shellcheck disable=SC2154
PS1='\D{%F %T} ${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '

# Colorise "ls" command output
eval "$(dircolors)"
alias ls='ls -A --color=auto'
alias l='ls -lh'
alias ll='l -L'

# Quick APT upgrade alias
alias APT='apt clean && apt update && apt list --upgradeable && apt full-upgrade && apt autopurge'

# Prevent accidental removals and make them verbose
alias rm='rm -RiIv'
alias mv='mv -iv'
alias cp='cp -iv'
