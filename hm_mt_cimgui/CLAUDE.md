# PROJECT_NAME

cimgui (Dear ImGui, via GLFW + OpenGL3) GUI app on hm_core (raddbg-derived C library), **true multi-TU fork**, Linux port. Library conventions, types, memory/string APIs, naming, and hard rules:

@src/_hm_core/CLAUDE.md

## Build & run

- `make` (release) / `make debug` / `make run` / `make clean` — needs `clang` on `PATH`. Output: `bin/PROJECT_NAME`.
- TU model: same as `hm_mt` — every real hm_core `.c` file under `src/_hm_core/{base,os,ext,log,tui,http,linux/base}` compiles as its own TU (see `Makefile`'s `CORE_SRCS`), same for `.c` files directly under `src/`.
- Flags: `-D_GNU_SOURCE -DBUILD_CONSOLE_INTERFACE=1 -DBUILD_MULTI_TU=1`, plus `-DCIMGUI_DEFINE_ENUMS_AND_STRUCTS -DCIMGUI_USE_GLFW -DCIMGUI_USE_OPENGL3` for cimgui.

## cimgui/GLFW are not part of hm_core's GUI stack

This app drives its own window and render loop directly through GLFW + OpenGL3 — it does **not** use hm_core's own `draw/`/`render/`/`ui/`/`window_manager/` layers (those stay uncompiled here; `OS_FEATURE_GRAPHICAL` is never defined, so `wm_init`/`fp_init`/`r_init`/`fnt_init` never run). Only `base/os/ext/log` are borrowed from hm_core. If you want hm_core's own immediate-mode UI stack instead of cimgui, that's a different (currently unported-to-Linux) scaffold flavor — see `_hm_core_mt`'s README "What's missing".

## Vendor libs (`vendor/`)

- `vendor/cimgui/{include,lib}` and `vendor/glfw/{include,lib}` are **committed to git** — a fresh clone builds with no extra setup beyond `clang`/GL/X11 runtime libs already on the system.
- `vendor/build_vendor.sh` rebuilds them from source (cimgui `docking`-free master + GLFW 3.4) — run it again to bump versions. It clones into a scratch `vendor/_build_tmp/` and deletes it when done; nothing but the built `.a`/headers persists.
- GLFW was built with **both X11 and Wayland backends** (GLFW vendors the Wayland protocol XML itself, so no extra system package was needed) — it picks the backend at runtime. Static linking pulls in both object sets regardless, which is why `Makefile`'s `LDFLAGS` links both the X11 libs and `-lwayland-client -lwayland-cursor -lwayland-egl -lxkbcommon`.
- `cimgui_impl.h` is hand-written (not the generated one, which needs luajit) — just the GLFW+OpenGL3 backend declarations this app actually calls. Include order matters: `cimgui.h` (defines `ImDrawData`) → `GLFW/glfw3.h` (defines `GLFWwindow`) → `cimgui_impl.h`.

## Entry contract

- Define `internal void entry_point(CmdLine *cmdline)` — never `main()` (the base layer owns it: `src/_hm_core/linux/base/linux_base.c`'s `main()` → `main_thread_base_entry_point` → `entry_point`). The GLFW/cimgui window + render loop lives inside `entry_point`, same as any other app-level work.

## Gotchas

- `igGetIO_Nil()`, not `igGetIO()` — this cimgui version's docking-free IO getter takes no viewport arg.
- `ImGui_ImplGlfw_InitForOpenGL`, not `..._InitForOther` — DX11-flavored scaffolds (Windows) use the latter; this one's OpenGL3.
- imgui.ini is written to `~/.config/PROJECT_NAME/imgui.ini` (see `src/config.c`), not the CWD.
- This scaffold copies the core in from `$HMCOREMT_ROOT` at project-creation time (not referenced live like `--use-env` projects) — pulling in upstream core changes means re-running `new-cproject` (or manually re-copying), not just rebuilding.
