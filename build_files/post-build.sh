#!/bin/bash

set -ouex pipefail

# Disable Terra again — build.sh only enabled it temporarily for the install
# step above; third-party repos ship disabled by default.
rum config-manager --set-disabled terra

# Write the DE identifier so rakuos-overlay-mount can detect a DE change at
# boot and trigger a soft reset to rebuild the overlay from packages.list.
echo "niri" > /usr/share/rakuos/de-name

# Belt-and-suspenders cleanup: earlier build steps (rum installs enabling
# systemd units, akmods, cryptsetup, etc.) can leave real runtime state
# behind in /run and /tmp inside the build container — content that only
# ever makes sense on a live booted system. `bootc container lint`'s
# runtime-deps/nonempty-run-tmp checks fail the build on it (and stray mount/
# device-adjacent state under /run can even trip the lint's "path led outside
# of the filesystem" runtime-deps check). Clear both right before the image
# layer is committed so the lint step always sees a clean, boot-fresh state
# regardless of what any earlier step happened to leave behind.
echo "[rakuos] Clearing runtime-only state from /run and /tmp before lint..."
find /run -mindepth 1 -delete 2>/dev/null || true
find /tmp -mindepth 1 -delete 2>/dev/null || true
