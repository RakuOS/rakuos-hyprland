#!/bin/bash

set -ouex pipefail

# Disable Terra again — build.sh only enabled it temporarily for the install
# step above; third-party repos ship disabled by default.
rum config-manager --default --set-disabled terra
rum config-manager --default --set-disabled 'rpmfusion-*'

# Write the DE identifier so rakuos-overlay-mount can detect a DE change at
# boot and trigger a soft reset to rebuild the overlay from packages.list.
echo "hyprland" > /usr/share/rakuos/de-name


# Override the uwsm session entry AFTER rum install (the hyprland-uwsm RPM
# owns /usr/share/wayland-sessions/hyprland-uwsm.desktop and would clobber a
# plain COPY). /usr/local is a symlink to /var/usrlocal in the base image, so
# it cannot be used as a COPY destination either — rewriting here is the only
# reliable spot. UWSM_SILENT_START=2 stops uwsm start from printing its
# progress to stdout (the display manager forwards it to the VT, showing text
# between the greeter and Hyprland); real errors still surface via syslog/journal.
mkdir -p /usr/share/wayland-sessions
cat > /usr/share/wayland-sessions/hyprland-uwsm.desktop << 'EOF'
[Desktop Entry]
Name=Hyprland (uwsm-managed)
Comment=An intelligent dynamic tiling Wayland compositor
Exec=env UWSM_SILENT_START=2 uwsm start -e -D Hyprland hyprland.desktop
TryExec=uwsm
DesktopNames=Hyprland
Type=Application
EOF


## Drop the nvidia-settings X11 autostart.
# /etc/xdg/autostart/nvidia-settings-load.desktop ships with the
# nvidia-settings RPM and runs:
#   sh -c "[ -e /dev/nvidia0 ] && exec /usr/bin/nvidia-settings --load-config-only"
# It has no OnlyShowIn/NotShowIn guard, so it fires on every login. Its only
# purpose is preloading ~/.nvidia-settings-rc for an X11 session, and this image
# has no X11 session (/usr/share/xsessions is empty — SDDM was replaced by
# greetd). On a hybrid laptop /dev/nvidia0 still exists, so the guard passes and
# nvidia-settings — an X11/GTK tool — then exits 1 under Wayland, leaving
# app-nvidia\x2dsettings\x2dload@autostart.service failed in `systemctl --user`
# on every single login. Pure noise with nothing reading its output.
# Reappears if the nvidia-settings RPM is upgraded or reinstalled.
rm -f /etc/xdg/autostart/nvidia-settings-load.desktop


## Hide uuctl and swash from the launcher; both stay runnable from a terminal.
# NoDisplay=true rather than rm: both .desktop files are RPM-owned (uwsm, swash)
# so a delete returns on upgrade, while this reapplies on every rebuild.
for _entry in uuctl.desktop dev.lemmy.swash.desktop; do
    _path="/usr/share/applications/$_entry"
    [ -f "$_path" ] || continue
    if grep -q '^NoDisplay=' "$_path"; then
        sed -i "s/^NoDisplay=.*/NoDisplay=true/" "$_path"
    else
        # NoDisplay belongs in the Desktop Entry group; appending is valid there.
        printf 'NoDisplay=true\n' >> "$_path"
    fi
done
unset _entry _path
