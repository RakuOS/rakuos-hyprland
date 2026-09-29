#!/bin/bash

set -ouex pipefail

# Disable Terra again — build.sh only enabled it temporarily for the install
# step above; third-party repos ship disabled by default.
rum config-manager --set-disabled terra

# Write the DE identifier so rakuos-overlay-mount can detect a DE change at
# boot and trigger a soft reset to rebuild the overlay from packages.list.
echo "niri" > /usr/share/rakuos/de-name

