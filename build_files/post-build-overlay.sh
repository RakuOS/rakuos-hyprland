#!/usr/bin/env bash
# post-build-overlay.sh
# Runs inside the container build (Containerfile RUN step / GitHub Actions).
#
# Does NOT install packages — that's impossible inside a container build
# because overlayfs on /usr requires CAP_SYS_ADMIN and a real kernel mount.
#
# Instead, this script seeds /usr/share/factory/var/lib/rakuos/ so the first
# deployed system gets a populated /var/lib/rakuos/ state:
#   - packages.list populated from /usr/share/rakuos/packages.list
#   - overlay upper/work dirs created and empty
#   - overlay.state intentionally absent
#
# On first boot, rakuos-overlay-sync.service sees the missing state file,
# treats it as a fresh/reset system, and performs a full install into the
# overlay automatically — no user interaction needed.
#
# Usage (from your Containerfile):
#   RUN /usr/libexec/rakuos/build/post-build-overlay.sh

set -euo pipefail

DEFAULT_PACKAGES_LIST="/usr/share/rakuos/packages.list"
Dnf_CONF="/usr/share/rakuos/dnf.conf"
FACTORY_VAR_ROOT="/usr/share/factory/var"
PACKAGES_LIST="$FACTORY_VAR_ROOT/lib/rakuos/packages.list"
UPPER_DIR="$FACTORY_VAR_ROOT/lib/rakuos/overlay/upper"
WORK_DIR="$FACTORY_VAR_ROOT/lib/rakuos/overlay/work"
STATE_FILE="$FACTORY_VAR_ROOT/lib/rakuos/overlay.state"
DIRTY_FILE="$FACTORY_VAR_ROOT/lib/rakuos/overlay.dirty"
PKG_CACHE_DIR="$FACTORY_VAR_ROOT/cache/libdnf5"
PKGCACHE_MIGRATED="$FACTORY_VAR_ROOT/lib/rakuos/pkgcache.migrated"
BASE_RPM_DB="/usr/share/rpm"
IMAGE_PACKAGES_TOML="/usr/lib/sysimage/libdnf5/packages.toml"

echo "[rakuos] Seeding overlay state for first-boot install..."

prebake_overlay_from_installroot() {
    local dnf_conf="/usr/share/rakuos/dnf.conf"
    local releasever=""
    local installroot
    local -a prebake_packages=()

    if [[ ! -f "$dnf_conf" ]]; then
        echo "[rakuos] WARNING: Missing $dnf_conf; skipping overlay prebake."
        return 0
    fi

    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        releasever="${VERSION_ID:-}"
    fi
    if [[ -z "$releasever" ]]; then
        echo "[rakuos] WARNING: Could not determine releasever; skipping overlay prebake."
        return 0
    fi

    mapfile -t prebake_packages < <(
        grep -v '^\s*#' "$PACKAGES_LIST" \
        | grep -v '^\s*$' \
        | sed 's/\s*#.*//' \
        | tr -s ' \t' '\n' \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
        | grep -v '^$'
    )

    if [[ ${#prebake_packages[@]} -eq 0 ]]; then
        echo "[rakuos] No overlay packages listed; skipping prebake."
        return 0
    fi

    installroot="$(mktemp -d /var/tmp/rakuos-overlay-installroot.XXXXXX)"
    trap 'rm -rf "$installroot"' RETURN

    echo "[rakuos] Prebaking overlay packages into installroot..."
    mkdir -p "$installroot/var/cache/libdnf5"
    mkdir -p "$installroot/usr/share/rpm"
    cp -a "$BASE_RPM_DB/." "$installroot/usr/share/rpm/"
    rm -f "$installroot/usr/share/rpm"/.rpm.lock "$installroot/usr/share/rpm"/__db.*
    if [[ -f "$IMAGE_PACKAGES_TOML" ]]; then
        mkdir -p "$installroot/usr/lib/sysimage/libdnf5"
        cp -a "$IMAGE_PACKAGES_TOML" "$installroot/usr/lib/sysimage/libdnf5/packages.toml"
    fi

    dnf5.real --config="$dnf_conf" \
        --use-host-config \
        --installroot="$installroot" \
        --releasever="$releasever" \
        --setopt=keepcache=1 \
        --setopt=cachedir="$installroot/var/cache/libdnf5" \
        --setopt=tsflags=noscripts \
        install -y --refresh "${prebake_packages[@]}"

    echo "[rakuos] Copying prebaked /usr payload into overlay upper..."
    rm -rf "$UPPER_DIR" "$WORK_DIR" "$PKG_CACHE_DIR"
    mkdir -p "$UPPER_DIR" "$WORK_DIR" "$PKG_CACHE_DIR"
    cp -a "$installroot/usr/." "$UPPER_DIR/"
    mkdir -p "$UPPER_DIR/share/rpm"
    cp -a "$installroot/usr/share/rpm/." "$UPPER_DIR/share/rpm/"
    rm -f "$UPPER_DIR/share/rpm"/.rpm.lock "$UPPER_DIR/share/rpm"/__db.*

    if [[ -d "$installroot/etc" ]] && [[ -n "$(ls -A "$installroot/etc" 2>/dev/null)" ]]; then
        echo "[rakuos] Copying prebaked /etc payload into image..."
        cp -a "$installroot/etc/." /etc/
    fi

    if [[ -d "$installroot/var/cache/libdnf5" ]] && [[ -n "$(ls -A "$installroot/var/cache/libdnf5" 2>/dev/null)" ]]; then
        echo "[rakuos] Copying libdnf5 cache into image..."
        cp -a "$installroot/var/cache/libdnf5/." "$PKG_CACHE_DIR/"
    fi

    touch "$PKGCACHE_MIGRATED"
    echo "prebaked-installroot" > "$STATE_FILE"
    rm -f "$DIRTY_FILE"

    echo "[rakuos] Overlay prebake complete."
}

# ── Create runtime dirs ───────────────────────────────────────────────────────

mkdir -p "$FACTORY_VAR_ROOT/lib/rakuos"
mkdir -p "$UPPER_DIR"
mkdir -p "$WORK_DIR"

# ── Seed packages.list ────────────────────────────────────────────────────────

if [[ -f "$DEFAULT_PACKAGES_LIST" ]]; then
    cp "$DEFAULT_PACKAGES_LIST" "$PACKAGES_LIST"
    PKG_COUNT=$(grep -v '^\s*#' "$PACKAGES_LIST" | grep -v '^\s*$' | wc -l)
    echo "[rakuos] packages.list seeded with $PKG_COUNT packages."
else
    echo "[rakuos] WARNING: No default packages.list at $DEFAULT_PACKAGES_LIST"
    echo "[rakuos] Creating empty packages.list — no packages will be installed on first boot."
    touch "$PACKAGES_LIST"
fi

# ── Ensure stale state is cleared before prebake writes fresh state ───────────
rm -f "$STATE_FILE" "$DIRTY_FILE"

# Ensure packages.list ends with newline
sed -i -e '$a\' "$PACKAGES_LIST"

echo "[rakuos] stale overlay state cleared — prebake will write fresh first-boot state."
echo "[rakuos] Post-build seed complete."

echo "Appending niri protected packages to protected-packages.txt..."
cat >> /usr/share/rakuos/protected-packages.txt << 'EOF'

# Niri packages (from rakuos-niri/build_files/build.sh)
  niri
  dms
  dankcalendar-git
  danksearch
  dgop
  dms-greeter
  nm-connection-editor
  pavucontrol
  ddcutil
  adw-gtk3-theme
  file-roller
  fprintd-pam
  gnome-calculator
  gnome-disk-utility
  gvfs-nfs
  ibus-mozc
  ibus-unikey
  nautilus
  gvfs
  gvfs-mtp
  cava
  wl-clipboard
  matugen
  quickshell
  wtype
  qt6ct-kde
  wl-mirror
  libnotify
  blueman
  gnome-keyring
  xwayland-satellite
  NetworkManager-adsl
  NetworkManager-bluetooth
  NetworkManager-ppp
  NetworkManager-wwan
  pipewire
  ghostty
  rakuos-software-gtk
  rakuos-welcome-gtk
  systemd-oomd-defaults
  wireplumber
  xdg-desktop-portal
  xdg-desktop-portal-gnome
  xdg-desktop-portal-gtk
  xdg-user-dirs-gtk
EOF
dnf5.real -y remove selinux-policy\* selinux-policy-targeted selinux-policy-devel policycoreutils-gui
dnf5.real -y install libselinux

# selinux-policy is fully removed on RakuOS (AppArmor is the sole MAC), but the
# baked-in rpm-ostree treefile still defaults "selinux": true. rpm-ostree reads
# that flag on every deploy-time layering operation and tries to load a policy
# from / that no longer exists, causing spurious sepolicy-mismatch failures.
if [ -f /usr/share/rpm-ostree/treefile.json ]; then
    sed -i 's/"selinux": *true/"selinux": false/' /usr/share/rpm-ostree/treefile.json
fi

echo "Generating base file manifest..."
/usr/libexec/rakuos/generate-base-manifest

echo "Prebaking niri overlay payload..."
prebake_overlay_from_installroot
