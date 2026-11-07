# One Containerfile for every image in this repo. CI picks the image with
# build args instead of a separate Containerfile per image:
#
#   BASE_IMAGE_REPO / BASE_IMAGE_TAG  the rakuos-base image to build FROM
#                       (its v2/v3/v4 and NVIDIA flavor sets this image's)
#   RAKUOS_GPU          none, or nvidia for the NVIDIA images (runs nvidia.sh)
#   RAKUOS_STAGING      1 on the staging branch (-staging packages)
#
# Global build args: available to the FROM line below.
ARG BASE_IMAGE_TAG="latest"
ARG BASE_IMAGE_REPO="quay.io/rakuos/rakuos-base"
ARG CHUNKAH_CONFIG_STR

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

FROM ${BASE_IMAGE_REPO}:${BASE_IMAGE_TAG} AS builder
ARG BASE_IMAGE_TAG
ENV BASE_IMAGE_TAG=${BASE_IMAGE_TAG}
# Set by CI to "1" on the staging branch so build.sh installs the
# -staging variants of the RakuOS packages.
ARG RAKUOS_STAGING="0"
ENV RAKUOS_STAGING=${RAKUOS_STAGING}
ARG RAKUOS_GPU="none"

COPY system_files /

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    set -e; \
    /ctx/build.sh; \
    case "${RAKUOS_GPU}" in \
      none) ;; \
      nvidia) /ctx/nvidia.sh ;; \
      *) echo "Unknown RAKUOS_GPU '${RAKUOS_GPU}' (want none or nvidia)" >&2; exit 1 ;; \
    esac; \
    /ctx/post-build.sh; \
    /ctx/post-build-overlay.sh; \
    /ctx/assign-components.sh generated; \
    /ctx/reset-mtimes.sh

COPY system_files /

# Clean up real runtime state (systemd units started mid-build, akmods/
# cryptsetup/etc. lock and socket files) that only ever makes sense on a
# live booted system, before the lint step inspects the committed image.
# This runs as its own RUN, after every mounted (--mount=type=secret/
# cache/tmpfs) build step above has already finished and unmounted, so it
# only ever touches plain files already baked into the layer — never a
# live mount the build engine itself still has open.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,source=system_files,target=/run/rakuos-system-files,ro \
    /ctx/assign-components.sh files rakuos-hyprland-files /run/rakuos-system-files; \
    find /run -mindepth 1 -delete 2>/dev/null || true; \
    find /tmp -mindepth 1 -delete 2>/dev/null || true; \
    find /boot -mindepth 1 -delete 2>/dev/null || true; \
    /ctx/reset-mtimes.sh

# RUN bootc container lint

# chunkah v0.7.1, pinned: another version can plan layers differently,
# which would change every layer of the next update.
FROM quay.io/coreos/chunkah@sha256:71e593421c5de7dcc7c8c5c50e98d3bac572055a76f399f61a491d123c20a523 AS chunkah
# org.rakuos.kernel.release: the kernel release of this image, what `uname -r`
# shows once it's booted, read from the finished root filesystem (the only
# kernel with a vmlinuz). It can't be a CI --label like
# org.rakuos.fedora.version: the kernel is only known after the build.
ARG CHUNKAH_CONFIG_STR
RUN --mount=from=builder,src=/,target=/chunkah,ro \
    --mount=type=bind,target=/run/src,rw \
        KREL=$(basename "$(dirname "$(ls /chunkah/usr/lib/modules/*/vmlinuz | head -1)")") && \
        [ -n "$KREL" ] && \
        chunkah build --prune /sysroot/ --max-layers 256 --compressed --threads 4 \
          --label ostree.commit- --label ostree.final-diffid- \
          --label "org.rakuos.kernel.release=${KREL}" \
          > /run/src/out.ociarchive

FROM oci-archive:out.ociarchive
LABEL containers.bootc=1
