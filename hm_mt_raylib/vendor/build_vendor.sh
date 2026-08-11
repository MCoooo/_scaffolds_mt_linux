#!/usr/bin/env bash
# build_vendor.sh — build raylib (static) for the hm_mt_raylib scaffold.
# Run once after cloning, or whenever you want to bump raylib's version
# (edit the tag below).
#
# raylib bundles its own GLFW-equivalent (rglfw) and builds it internally —
# unlike hm_mt_cimgui, there's no separate GLFW vendor step here. Same X11
# dev headers as hm_mt_cimgui are still needed at link time (rglfw talks to
# X11 directly), no new system deps beyond those.
#
# Requires: make, gcc, git, X11 dev headers
#   apt install build-essential git libx11-dev libxrandr-dev libxi-dev libxcursor-dev libxinerama-dev libxxf86vm-dev libgl-dev
set -euo pipefail

VENDOR="$(cd "$(dirname "$0")" && pwd)"
BUILD_TMP="$VENDOR/_build_tmp"
mkdir -p "$BUILD_TMP"

# ---- raylib ---------------------------------------------------------------
RAYLIB_SRC="$BUILD_TMP/raylib"
if [[ ! -d "$RAYLIB_SRC" ]]; then
    git clone --depth 1 --branch 6.0 https://github.com/raysan5/raylib.git "$RAYLIB_SRC"
fi

make -C "$RAYLIB_SRC/src" PLATFORM=PLATFORM_DESKTOP RAYLIB_LIBTYPE=STATIC -j"$(nproc)"

mkdir -p "$VENDOR/raylib/include" "$VENDOR/raylib/lib"
cp "$RAYLIB_SRC/src/libraylib.a" "$VENDOR/raylib/lib/libraylib.a"
cp "$RAYLIB_SRC/src/raylib.h" "$RAYLIB_SRC/src/raymath.h" "$RAYLIB_SRC/src/rlgl.h" "$VENDOR/raylib/include/"
echo "[+] raylib/lib/libraylib.a"

rm -rf "$BUILD_TMP"
echo "[+] Done."
