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

## Install packages
# FIXME: Remove quickshell-git when Fedora gets 0.3 version
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
  xwayland-satellite \
  NetworkManager-adsl \
  NetworkManager-bluetooth \
  NetworkManager-ppp \
  NetworkManager-wwan \
  pipewire \
  ghostty \
  ${RAKUOS_RELEASE_PKG} \
  rakuos-software-gtk \
  rakuos-welcome-gtk \
  systemd-oomd-defaults \
  wireplumber \
  xdg-desktop-portal \
  xdg-desktop-portal-gnome \
  xdg-desktop-portal-gtk \
  xdg-user-dirs-gtk

rum remove -y waybar swaylock alacritty fuzzel

## Remove fedora wallpapers
rm -r /usr/share/backgrounds/fedora-workstation/

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
