#!/usr/bin/env bash
# Build the Linux x86_64 release export template inside the Steam Runtime
# "sniper" image from ./Dockerfile and copy it out to the host.
#
#   ./build-godot-sniper.sh [output-dir]    (default: bin/sniper)
#
# Every run is a full build from a fresh copy of the working tree, so object
# files from host builds in bin/obj never end up in the template.
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

IMAGE=godot-sniper-build
OUT_DIR=$(realpath -m "${1:-bin/sniper}")

# The Dockerfile has no COPY, so build it without sending a context.
docker build -t "$IMAGE" - < Dockerfile

# Create it as ourselves, otherwise Docker creates it owned by root.
mkdir -p "$OUT_DIR"

# Stream tracked and untracked (but not ignored) files into the container,
# which keeps uncommitted changes but leaves out bin/. .git is mounted
# read-only so the build can embed the commit hash and timestamp.
git ls-files -z --cached --others --exclude-standard \
    | tar --null --files-from=- --ignore-failed-read -c \
    | docker run -i --rm \
        --user "$(id -u):$(id -g)" \
        -v "$PWD/.git:/git:ro" \
        -v "$OUT_DIR:/out" \
        "$IMAGE" \
        bash -euo pipefail -c '
            mkdir /tmp/build
            cd /tmp/build
            tar -x
            ln -s /git .git
            scons platform=linuxbsd arch=x86_64 target=template_release production=yes
            cp bin/godot.linuxbsd.template_release.x86_64 /out/
        '

echo "Export template written to $OUT_DIR/godot.linuxbsd.template_release.x86_64"
