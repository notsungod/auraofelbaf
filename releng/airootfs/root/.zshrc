#
# ~/.bashrc
# nmtui,imdum,winq,winc...
chmod 755 /usr/local/bin/apfsck
chmod 755 /usr/local/bin/swww-daemon
chmod 755 /usr/local/bin/mkapfs
chmod 755 /usr/local/bin/fsck.apfs
chmod 755 /usr/local/bin/mkfs.apfs
chmod 755 /usr/local/bin/ttyscheme
chmod 755 /usr/local/bin/swww
ttyscheme lavandula
# If not running interactively, don't do anything
alias con='wpa_supplicant -c /etc/wpa_supplicant/wpa_supplicant.conf -i'
alias x='sudo $(history -p !!)'
alias n=nvim
alias l='ls --color=auto -lah'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
eval "$(starship init zsh)"
echo -e '\033[?1c'
cursor_style_full_block=16
if [ -z "$KITTY_PID" ] && [ -z "$NVIM_ACTIVE" ]; then
    export NVIM_ACTIVE=y
    tmux
fi
alias imdum='Hyprland --i-am-really-stupid && swww img ~/wallpaper/auraofelbaf.png'
