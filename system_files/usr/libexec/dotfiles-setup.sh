#!/bin/bash

FIRSTRUN="$HOME/.local/share/config-setup"
OLDRUN="$HOME/.local/share/dotfiles-setup"

if [ -f "$OLDRUN" ]; then
    rm "$OLDRUN"
fi

if [ -f "$FIRSTRUN" ]; then
    exit 0
fi

cp -r "/etc/skel/." "$HOME"
gsettings set org.gnome.desktop.interface icon-theme "Colloid-Dark"
dms restart

# Fixme: Temporary replace ibus
ENV_LINE='export GTK_IM_MODULE="simple"'
FISH_CONF="$HOME/.config/fish/config.fish"
FISH_LINE='set -gx GTK_IM_MODULE "simple"'

echo "$ENV_LINE" >> "$HOME/.bash_profile"
echo "$ENV_LINE" >> "$HOME/.zshrc"
echo "$FISH_LINE" >> "$FISH_CONF"

touch "$FIRSTRUN"
