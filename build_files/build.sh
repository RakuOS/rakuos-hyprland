#!/bin/bash

set -ouex pipefail

FEDORA_VERSION=$(rpm -E %fedora)

# On the staging branch (RAKUOS_STAGING=1, set via --build-arg from CI)
# install the staging os-release identity instead of the stable one, so
# staging images identify themselves as "RakuOS NIRI Staging".
RAKUOS_RELEASE_PKG="rakuos-release-niri"
if [ "${RAKUOS_STAGING:-0}" = "1" ]; then
    RAKUOS_RELEASE_PKG="rakuos-release-niri-staging"
fi

# Terra ships disabled by default (third-party repos are opt-in), so enable
# it here in case any packages below come from Terra; post-build.sh disables
# it again before the image is finalized.
rum config-manager --set-enabled terra

## Install packages
# FIXME: Remove quickshell-git when Fedora gets 0.3 version
# ghostty-kio satisfies ghostty's rich Requires (`ghostty-kio = ... if
# kf6-kio-core`); without it baked in now, any later kf6-kio-core install
# (e.g. kde-partitionmanager) fails once Terra is disabled below.
rum install -y \
  niri \
  dms \
  dankcalendar-git \
  danksearch \
  dgop \
  dms-greeter \
  nm-connection-editor \
  pavucontrol \
  ddcutil \
  adw-gtk3-theme \
  file-roller \
  fprintd-pam \
  gnome-calculator \
  gnome-disk-utility \
  gvfs-nfs \
  ibus-mozc \
  ibus-unikey \
  nautilus \
  cups-pk-helper \
  tuned \
  tuned-ppd \
  gvfs \
  gvfs-mtp \
  cava \
  wl-clipboard \
  matugen \
  quickshell-git \
  wtype \
  qt6ct-kde \
  wl-mirror \
  libnotify \
  blueman \
  gnome-keyring \
  gnome-keyring-pam \
  xwayland-satellite-0:0.8.1-1.fc44 \
  NetworkManager-adsl \
  NetworkManager-bluetooth \
  NetworkManager-ppp \
  NetworkManager-wwan \
  pipewire \
  pipewire-pulseaudio \
  ghostty \
  ghostty-nautilus \
  ghostty-kio \
  ${RAKUOS_RELEASE_PKG} \
  rakuos-software-gtk \
  rakuos-system-gtk \
  rakuos-welcome-gtk \
  systemd-oomd-defaults \
  wireplumber \
  xdg-desktop-portal \
  xdg-desktop-portal-gnome \
  xdg-desktop-portal-gtk \
  xdg-user-dirs-gtk

rum remove -y waybar swaylock alacritty fuzzel

## Remove fedora wallpapers
#rm -r /usr/share/backgrounds/fedora-workstation/

## Fix default applications
sed -i \
  -e '/text\/plain=org\.gnome\.gedit\.desktop/d' \
  -e '/org\.gnome\.eog\.desktop/d' \
  -e '/org\.gnome\.Totem\.desktop/d' \
  -e '/org\.gnome\.Rhythmbox3\.desktop/d' \
  -e 's|application/pdf=org\.gnome\.Evince\.desktop|application/pdf=org.mozilla.firefox.desktop|g' \
  /usr/share/applications/mimeapps.list

## Unlock keyring on login
sed -i -E 's/^-([a-z]+[[:space:]]+.*pam_gnome_keyring\.so)/\1/' /etc/pam.d/greetd

## Enable Services
systemctl enable greetd
systemctl enable --global dotfiles-setup
systemctl enable --global dsearch dms
