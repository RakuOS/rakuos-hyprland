#!/bin/bash

# First-login populator: copy /etc/skel into $HOME once per DE. The installer
# creates users without a full skeleton, so Hyprland's modular config never
# lands in the home without this.
#
# Marker is keyed by DE, not just "already populated": $HOME survives an image
# switch while /etc/skel does not, so an unqualified marker would make the new
# DE skip its skel. Keying per-DE re-triggers the copy per image instead.
#
# de-name is written by post-build.sh (also used by rakuos-overlay-mount).
# SKEL_ROOT / DE_NAME_FILE are overridable for testing the copy logic.
SKEL_ROOT="${SKEL_ROOT:-/etc/skel}"
DE_NAME_FILE="${DE_NAME_FILE:-/usr/share/rakuos/de-name}"

DE="$(cat "$DE_NAME_FILE" 2>/dev/null || echo unknown)"
FIRSTRUN="$HOME/.local/share/config-setup-$DE"
OLDRUN="$HOME/.local/share/dotfiles-setup"

# Copy the official RakuOS wallpaper set straight from the read-only image so
# a later base-image update reaches existing users (and the skel stays small).
# Noctalia's picker reads ~/Pictures/Wallpapers; -n never overwrites a user file.
populate_wallpapers() {
    mkdir -p "$HOME/Pictures/Wallpapers"
    for _wpdir in /usr/share/wallpapers/RakuOS-*/; do
        [ -d "$_wpdir" ] || continue
        _wpimg=$(find "$_wpdir" -path '*/contents/images/*.png' | head -n1)
        if [ -n "$_wpimg" ]; then
            cp -n "$_wpimg" "$HOME/Pictures/Wallpapers/$(basename "$_wpdir").png"
        fi
    done
    [ -f /usr/share/wallpapers/default.jpg ] && \
        cp -n /usr/share/wallpapers/default.jpg "$HOME/Pictures/Wallpapers/default.jpg"
    unset _wpdir _wpimg
}

if [ -f "$FIRSTRUN" ]; then
    # Later logins: just top up any new wallpapers. cp -n is a no-op on existing.
    populate_wallpapers
    exit 0
fi

# Old build used dotfiles-setup as the marker; drop it so appearance keys below
# get applied to those users too.
[ -f "$OLDRUN" ] && rm -f "$OLDRUN"

# cp -rn keeps user edits: existing files are left alone, only missing ones are
# filled in. Deliberately no `set -e` -- a partial copy must still reach the
# wallpaper sync and gsettings below.
if ! cp -rn "$SKEL_ROOT/." "$HOME"; then
    echo "[dotfiles-setup] skel copy reported errors; verifying result." >&2
fi

# Gate the marker on the whole skeleton being present. A non-zero cp status is
# ambiguous (real failure vs nothing to copy), so check directly: if anything is
# still missing, leave the marker absent and retry on the next login. Writing it
# now would strand the user on a permanently half-populated config.
missing=""
while IFS= read -r _f; do
    [ -e "$HOME/${_f#"$SKEL_ROOT"/}" ] || missing="${missing}\n  ${_f#"$SKEL_ROOT"/}"
done < <(find "$SKEL_ROOT" -type f -o -type l 2>/dev/null)

if [ -n "$missing" ]; then
    printf '[dotfiles-setup] skel incomplete, not writing marker (will retry next login):%b\n' "$missing" >&2
    exit 0
fi

populate_wallpapers

# GTK4 ignores gtk-icon-theme-name in settings.ini (verified: reports Adwaita no
# matter the value) and reads org.gnome.desktop.interface.icon-theme instead, so
# set it here. settings.ini keys stay for GTK3/file readers. Needs a session bus
# (unit is WantedBy=default.target); no-op if gsettings is unavailable.
if command -v gsettings > /dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface icon-theme "Colloid-Dark"
    # Same reason as the icon theme: the running session reads these from
    # gsettings, so the skel settings.ini keys are only a fallback. Inter is
    # the system UI font and Maple Mono NF the monospace one, shared by every
    # DE so a switch does not change the app font.
    gsettings set org.gnome.desktop.interface font-name "Inter 11"
    gsettings set org.gnome.desktop.interface monospace-font-name "Maple Mono NF 11"
fi

# First-run marker: ensure the dir exists so the touch below doesn't fail
# silently and re-run the whole block on every login.
mkdir -p "$(dirname "$FIRSTRUN")"
touch "$FIRSTRUN"