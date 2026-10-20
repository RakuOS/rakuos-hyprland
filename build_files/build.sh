#!/bin/bash

set -ouex pipefail

FEDORA_VERSION=$(rpm -E %fedora)

# On the staging branch (RAKUOS_STAGING=1, set via --build-arg from CI)
# install the staging os-release identity instead of the stable one, so
# staging images identify themselves as "RakuOS hyprland Staging".
RAKUOS_RELEASE_PKG="rakuos-release-hyprland"
if [ "${RAKUOS_STAGING:-0}" = "1" ]; then
    RAKUOS_RELEASE_PKG="rakuos-release-hyprland-staging"
fi

# Terra ships disabled by default (third-party repos are opt-in), so enable
# it here in case any packages below come from Terra; post-build.sh disables
# it again before the image is finalized.
rum config-manager --default --set-enabled terra
# RPM Fusion is disabled in the base image too; turn its default repos back
# on (the list base post-build.sh recorded). post-build.sh disables them again.
rum config-manager --default --set-enabled $(cat /usr/share/rakuos/rpmfusion-default-repos)

## Install packages
# FIXME: Remove quickshell-git when Fedora gets 0.3 version
# ghostty-kio satisfies ghostty's rich Requires (`ghostty-kio = ... if
# kf6-kio-core`); without it baked in now, any later kf6-kio-core install
# (e.g. kde-partitionmanager) fails once Terra is disabled below.
rum install -y --skip-broken --skip-unavailable \
  hyprland \
  hyprland-guiutils \
  uwsm \
  xorg-x11-server-Xwayland \
  egl-wayland \
  hyprpicker \
  grim \
  slurp \
  wtype \
  wl-clipboard \
  noctalia \
  noctalia-greeter \
  xdg-desktop-portal \
  xdg-desktop-portal-hyprland \
  xdg-desktop-portal-gtk \
  xdg-user-dirs-gtk \
  ghostty \
  ghostty-nautilus \
  ghostty-kio \
  jetbrainsmono-nerd-fonts \
  zsh-autosuggestions \
  zsh-syntax-highlighting \
  eza \
  bat \
  fzf \
  chafa \
  gum \
  zoxide \
  fastfetch \
  starship \
  swash \
  cliphist \
  cava \
  pavucontrol \
  pipewire \
  pipewire-alsa \
  pipewire-pulseaudio \
  wireplumber \
  NetworkManager-adsl \
  NetworkManager-bluetooth \
  NetworkManager-ppp \
  NetworkManager-wwan \
  nm-connection-editor \
  tuned \
  tuned-ppd \
  fprintd-pam \
  adw-gtk3-theme \
  bibata-cursor-theme \
  gvfs \
  gvfs-mtp \
  gvfs-nfs \
  gvfs-smb \
  qt6-qtdeclarative \
  qt6-qt5compat \
  qt6-qtsvg \
  qt6ct \
  qt6-qtimageformats \
  libnotify \
  systemd-oomd-defaults \
  gnome-calculator \
  gnome-disk-utility \
  nautilus \
  nomacs \
  cups-pk-helper \
  tesseract \
  tesseract-langpack-eng \
  tesseract-langpack-ind \
  zbar \
  ${RAKUOS_RELEASE_PKG} \
  rakuos-software-gtk \
  rakuos-system-gtk \
  rakuos-welcome-gtk \
  rakuos-shell-picker \

## Kitty is replaced by ghostty, and wofi is used by neither Noctalia nor the
## Noctalia Greeter. kitty-terminfo goes with it: ghostty ships its own
## xterm-ghostty terminfo, so a kitty terminal type is referenced by nothing.
rum remove -y wofi kitty kitty-kitten kitty-shell-integration kitty-terminfo 2>/dev/null || true

## Remove fedora wallpapers
#rm -r /usr/share/backgrounds/fedora-workstation/

## NTP so the clock stays synced across reboots. RTC is UTC on both sides already
## (Windows has RealTimeIsUniversal=1), so no timedatectl set-local-rtc needed.
rum install -y chrony
systemctl enable chronyd

## Noctalia Greeter setup. The greeter account must exist first or
## noctalia-greeter-apply-appearance --setup-system aborts the whole RUN step.
## uid/gid are left to useradd so they cannot collide with the base's range, and
## -m is omitted because setup_greeter_system.sh creates and owns /var/lib/greeter.
if ! getent passwd greeter >/dev/null; then
    useradd \
        --system \
        --home-dir /var/lib/greeter \
        --shell /bin/bash \
        --comment "System Greeter" \
        greeter
fi

## system_files/etc/greetd/config.toml is already in place (Containerfile COPYs
## system_files first). What the shipped script adds: pam_systemd.so in
## /etc/pam.d/greetd, else logind never makes a session/seat for the greeter's
## nested wlroots compositor; /var/lib/noctalia-greeter (0750, greeter:greeter);
/usr/share/noctalia-greeter/setup_greeter_system.sh

## tuned/tuned-ppd need no explicit enable: 90-default.preset already enables both,
## same as on the niri image.
systemctl enable greetd
systemctl enable --global dotfiles-setup
