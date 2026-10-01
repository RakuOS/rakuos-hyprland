#!/bin/bash

# First-login populator: copy /etc/skel into $HOME once per DE. The
# rakuos-installer creates users WITHOUT a full skeleton, so without this,
# Hyprland's modular config (hyprland.lua -> require("config.*")) never lands
# in the home and Hyprland falls back to its auto-generated default config.
#
# The marker is keyed by DE, not just "was this account ever populated".
# $HOME survives an image switch while /etc/skel does not, so a user moving
# from another DE image arrives here with their old marker already in place.
# A single unqualified marker answered "has this account been populated" --
# which the previous image had already made true -- so the skel was skipped and
# the user landed in Hyprland with no config at all. Keying the marker on the
# DE means the answer is re-checked per image: the old marker no longer
# matches, and the new DE's skel gets copied on the next login, with no need to
# create a throwaway account.
#
# de-name is written by post-build.sh in this same image
# (/usr/share/rakuos/de-name), which is also what rakuos-overlay-mount reads to
# detect a DE change for the overlay. Falling back to "unknown" keeps the
# script working if that file is somehow absent; it degrades to a single
# marker, which is the old behaviour rather than a hard failure.
#
# SKEL_ROOT / DE_NAME_FILE are overridable only so the copy-and-verify logic
# below can be exercised against a throwaway directory. Unset in normal
# operation, where they resolve to the real image paths.
SKEL_ROOT="${SKEL_ROOT:-/etc/skel}"
DE_NAME_FILE="${DE_NAME_FILE:-/usr/share/rakuos/de-name}"

DE="$(cat "$DE_NAME_FILE" 2>/dev/null || echo unknown)"
FIRSTRUN="$HOME/.local/share/config-setup-$DE"
OLDRUN="$HOME/.local/share/dotfiles-setup"

# Official RakuOS wallpaper set, copied straight out of the read-only image
# rather than through /etc/skel. Populating the skeleton at build time would
# mean a rebuild every time the base image ships new wallpapers, and it would
# put several MB into every /etc/skel in the image. Reading them here also
# means a wallpaper added by a later base image update reaches existing users
# on their next login, with no image rebuild.
#
# Noctalia's wallpaper picker reads ~/Pictures/Wallpaper, so that is where they
# need to land. -n never overwrites a file the user already has.
populate_wallpapers() {
    mkdir -p "$HOME/Pictures/Wallpaper"
    for _wpdir in /usr/share/wallpapers/RakuOS-*/; do
        [ -d "$_wpdir" ] || continue
        _wpimg=$(find "$_wpdir" -path '*/contents/images/*.png' | head -n1)
        if [ -n "$_wpimg" ]; then
            cp -n "$_wpimg" "$HOME/Pictures/Wallpaper/$(basename "$_wpdir").png"
        fi
    done
    [ -f /usr/share/wallpapers/default.jpg ] && \
        cp -n /usr/share/wallpapers/default.jpg "$HOME/Pictures/Wallpaper/default.jpg"
    unset _wpdir _wpimg
}

if [ -f "$FIRSTRUN" ]; then
    # Keep graphics in sync on later logins: copy any wallpaper the user does
    # not have yet. Safe to run every time, cp -n is a no-op on existing files.
    populate_wallpapers
    exit 0
fi

# An older build used dotfiles-setup as the marker. Drop it and fall through to
# the skel copy so the appearance keys below get applied to those users too.
[ -f "$OLDRUN" ] && rm -f "$OLDRUN"

# -n (no-clobber) matters now that the marker is per-DE: a user who switches
# images and back keeps whatever they already have. Files that already exist in
# $HOME are left exactly as they are -- including hand-edited config -- and
# only what is missing gets filled in. A plain `cp -r` would overwrite their
# edits with the skel version on every DE switch.
#
# This runs unguarded on purpose. The script has no `set -e`, and that is
# correct here: a partial copy must not abort the run before the wallpaper
# sync and the gsettings call below, which are wanted regardless.
#
# The exit status is checked separately because `cp -rn` reports failure for
# two very different situations:
#   - a real failure (unwritable destination, a type clash) -> the home is
#     incomplete, and writing the marker would strand the user on a
#     permanently half-populated config that never retries;
#   - nothing left to do (every skel file already present) -> benign.
# A non-zero status alone cannot tell them apart, and neither can spot-checking
# one file: the copy can fail on any single path while others succeed. So the
# marker is gated on the whole skeleton actually being present.
if ! cp -rn "$SKEL_ROOT/." "$HOME"; then
    echo "[dotfiles-setup] skel copy reported errors; verifying result." >&2
fi

# Gate: only mark this DE populated once its skeleton is really all there.
# Any file still missing after the copy means a partial home -- Hyprland would
# then start with a config whose require("config.*") targets are missing, or
# with no entry point at all and fall back to a generated default. Writing the
# marker in that state turns a transient failure (read-only home, out of
# space, a type clash) into a permanent one, so leave the marker absent and let
# the next login retry.
missing=""
while IFS= read -r _f; do
    # _f is a path under $SKEL_ROOT; the home is what must have it.
    [ -e "$HOME/${_f#"$SKEL_ROOT"/}" ] || missing="${missing}\n  ${_f#"$SKEL_ROOT"/}"
done < <(find "$SKEL_ROOT" -type f -o -type l 2>/dev/null)

if [ -n "$missing" ]; then
    printf '[dotfiles-setup] skel incomplete, not writing marker (will retry next login):%b\n' "$missing" >&2
    exit 0
fi

populate_wallpapers

## Apply the icon theme through GSettings, which is what actually decides icon
## lookup for GTK4 apps.
##
## This cannot be done from the skeleton. Verified on the skel itself: with
## gtk-icon-theme-name=Colloid-Dark in gtk-{3,4}.0/settings.ini,
## Gtk.Settings.get_default() reports gtk-theme-name=adw-gtk3-dark (so the file
## IS read) but still reports gtk-icon-theme-name=Adwaita, no matter what value
## is written -- including deliberately bogus ones. The key is not consulted for
## icon lookup on GTK4; org.gnome.desktop.interface.icon-theme is, and its
## compiled schema default is 'Adwaita'.
##
## The settings.ini keys are kept anyway: GTK3 apps and anything reading the
## file directly still honour them, so this is additive rather than a move.
##
## Noctalia's own GTK template (assets/templates/gtk/apply.sh) writes gtk-theme
## and color-scheme via gsettings but never icon-theme, so nothing else in the
## session sets this.
##
## Needs a session bus; the unit is WantedBy=default.target so it starts with
## the graphical session. If gsettings is unavailable this is a no-op and the
## user can always set the icon theme from the Noctalia/gsettings UI.
if command -v gsettings > /dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface icon-theme "Colloid-Dark"
fi

# $HOME/.local/share is not part of the skeleton, and a user created by
# rakuos-installer may not have it yet. Without this the touch below fails
# silently and the first-run block re-runs on every login, re-running the skel
# copy each time (harmless now that the copy is -n, but still wasteful and it
# re-applies the gsettings call on every login).
mkdir -p "$(dirname "$FIRSTRUN")"
touch "$FIRSTRUN"
