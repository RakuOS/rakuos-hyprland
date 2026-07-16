#!/bin/bash

FIRSTRUN="$HOME/.local/share/dotfiles-setup"

if [ -f "$FIRSTRUN" ]; then
    exit 0
fi

cp -r "/etc/skel/." "$HOME"
dms ipc theme dark
dms ipc wallpaper set /usr/share/backgrounds/rakuos/default.jpg

touch "$FIRSTRUN"
