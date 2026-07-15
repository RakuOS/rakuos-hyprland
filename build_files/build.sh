#!/bin/bash

set -ouex pipefail

FEDORA_VERSION=$(rpm -E %fedora)

## Install packages
dnf5.real -y install \
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
  xwayland-satellite \
  NetworkManager-adsl \
  NetworkManager-bluetooth \
  NetworkManager-ppp \
  NetworkManager-wwan \
  pipewire \
  ghostty \
  rakuos-software-gtk \
  rakuos-welcome-gtk \
  systemd-oomd-defaults \
  wireplumber \
  xdg-desktop-portal \
  xdg-desktop-portal-gnome \
  xdg-desktop-portal-gtk \
  xdg-user-dirs-gtk

dnf5.real -y remove waybar swaylock alacritty fuzzel

## Enable Services
systemctl enable greetd
systemctl enable --global dsearch dms
