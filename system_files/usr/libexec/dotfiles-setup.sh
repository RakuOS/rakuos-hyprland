#!/bin/bash

FIRSTRUN="$HOME/.local/share/dotfiles-setup"

if [ -f "$FIRSTRUN" ]; then
    exit 0
fi

cp -r "/etc/skel/." "$HOME"
gsettings set org.gnome.desktop.interface icon-theme "WhiteSur-dark"
dms restart

touch "$FIRSTRUN"
