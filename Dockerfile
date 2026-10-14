# Godot build environment on top of the Steam Runtime 3.0 "sniper" SDK.
#
# sniper is Debian 11 "bullseye" (glibc 2.31, GCC 10). Anything built in here
# runs on the Steam Deck and on distros far older than the build host.
#
#   docker build -t godot-sniper-build .
#
FROM registry.gitlab.steamos.cloud/steamrt/sniper/sdk:latest

ENV DEBIAN_FRONTEND=noninteractive

# Godot's own Debian dependency list, plus the X extensions its pkg-config
# checks look for (xext, xrender) and git for source/patch handling.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        pkg-config \
        python3 \
        python3-pip \
        git \
        ca-certificates \
        libx11-dev \
        libxcursor-dev \
        libxinerama-dev \
        libxi-dev \
        libxrandr-dev \
        libxext-dev \
        libxrender-dev \
        libgl1-mesa-dev \
        libglu1-mesa-dev \
        libasound2-dev \
        libpulse-dev \
        libudev-dev \
    && rm -rf /var/lib/apt/lists/*

# Wayland is optional. The steamrt apt repo is a curated subset of bullseye,
# so install these one by one and don't fail the image build if one is
# missing - Godot's linuxbsd detect.py disables Wayland by itself when
# wayland-scanner isn't found.
RUN apt-get update; \
    for p in libwayland-dev libwayland-bin libxkbcommon-dev; do \
        apt-get install -y --no-install-recommends "$p" || echo "!! skipping $p (not in steamrt repo)"; \
    done; \
    rm -rf /var/lib/apt/lists/*

# bullseye ships SCons 4.0.1, which is the bare minimum for Godot 4.5 and too
# old for 4.6+. Take a current one from PyPI; fall back to the distro package.
RUN pip3 install --no-cache-dir "SCons>=4.7,<5" \
    || (apt-get update \
        && apt-get install -y --no-install-recommends scons \
        && rm -rf /var/lib/apt/lists/*)

# The container runs as your host UID, so keep SCons' scratch files out of
# root-owned directories.
ENV HOME=/tmp
WORKDIR /src

RUN gcc --version && scons --version
