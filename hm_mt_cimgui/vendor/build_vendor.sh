#!/usr/bin/env bash
# build_vendor.sh — build GLFW and cimgui (with GLFW + OpenGL3 backends)
# for the hm_mt_cimgui scaffold. Run once after cloning, or whenever you
# want to update cimgui/GLFW versions (edit the tags/branches below).
#
# X11-only by design (no -DGLFW_BUILD_WAYLAND) — runs fine under XWayland
# on Wayland sessions; native Wayland needs the wayland-protocols package
# and is intentionally left out to keep the dependency footprint minimal.
#
# Requires: cmake, make, gcc, g++, git, X11 dev headers
#   apt install cmake g++ libx11-dev libxrandr-dev libxi-dev libxcursor-dev libxinerama-dev libxxf86vm-dev libgl-dev
set -euo pipefail

VENDOR="$(cd "$(dirname "$0")" && pwd)"
BUILD_TMP="$VENDOR/_build_tmp"
mkdir -p "$BUILD_TMP"

# ---- GLFW ----------------------------------------------------------------
GLFW_SRC="$BUILD_TMP/glfw"
if [[ ! -d "$GLFW_SRC" ]]; then
    git clone --depth 1 --branch 3.4 https://github.com/glfw/glfw.git "$GLFW_SRC"
fi
cmake -S "$GLFW_SRC" -B "$GLFW_SRC/build" \
    -DGLFW_BUILD_EXAMPLES=OFF \
    -DGLFW_BUILD_TESTS=OFF \
    -DGLFW_BUILD_DOCS=OFF \
    -DBUILD_SHARED_LIBS=OFF
cmake --build "$GLFW_SRC/build" --parallel
cp "$GLFW_SRC/build/src/libglfw3.a" "$VENDOR/glfw/lib/libglfw3.a"
cp -r "$GLFW_SRC/include/GLFW" "$VENDOR/glfw/include/"
echo "[+] glfw/lib/libglfw3.a"

# ---- cimgui + backends (direct compile, no cmake) ------------------------
CIMGUI_SRC="$BUILD_TMP/cimgui"
if [[ ! -d "$CIMGUI_SRC" ]]; then
    git clone --depth 1 --recurse-submodules https://github.com/cimgui/cimgui.git "$CIMGUI_SRC"
fi

OBJS_DIR="$BUILD_TMP/cimgui_objs"
mkdir -p "$OBJS_DIR"

IFLAGS="-I$CIMGUI_SRC -I$CIMGUI_SRC/imgui -I$VENDOR/glfw/include"

# Core imgui — C++ linkage is fine, cimgui.cpp wraps everything in extern "C"
g++ -c -O2 $IFLAGS "$CIMGUI_SRC/cimgui.cpp"                   -o "$OBJS_DIR/cimgui.o"
g++ -c -O2 $IFLAGS "$CIMGUI_SRC/imgui/imgui.cpp"              -o "$OBJS_DIR/imgui.o"
g++ -c -O2 $IFLAGS "$CIMGUI_SRC/imgui/imgui_draw.cpp"         -o "$OBJS_DIR/imgui_draw.o"
g++ -c -O2 $IFLAGS "$CIMGUI_SRC/imgui/imgui_demo.cpp"         -o "$OBJS_DIR/imgui_demo.o"
g++ -c -O2 $IFLAGS "$CIMGUI_SRC/imgui/imgui_tables.cpp"       -o "$OBJS_DIR/imgui_tables.o"
g++ -c -O2 $IFLAGS "$CIMGUI_SRC/imgui/imgui_widgets.cpp"      -o "$OBJS_DIR/imgui_widgets.o"

# Backends — force extern "C" so C code can link without name mangling
IMPL_FLAGS=("-DIMGUI_IMPL_API=extern \"C\"")
g++ -c -O2 $IFLAGS "${IMPL_FLAGS[@]}" "$CIMGUI_SRC/imgui/backends/imgui_impl_glfw.cpp"    -o "$OBJS_DIR/imgui_impl_glfw.o"
g++ -c -O2 $IFLAGS "${IMPL_FLAGS[@]}" "$CIMGUI_SRC/imgui/backends/imgui_impl_opengl3.cpp" -o "$OBJS_DIR/imgui_impl_opengl3.o"

ar rcs "$VENDOR/cimgui/lib/libcimgui.a" "$OBJS_DIR"/*.o
cp "$CIMGUI_SRC/cimgui.h" "$VENDOR/cimgui/include/"
echo "[+] cimgui/lib/libcimgui.a"

rm -rf "$BUILD_TMP"
echo "[+] Done."
