# PROJECT_NAME

raylib 6.x (static) app on hm_core (raddbg-derived C library), **true multi-TU fork**, Linux port. Library conventions, types, memory/string APIs, naming, and hard rules:

@src/_hm_core/CLAUDE.md

## Build & run

- `make` (release) / `make debug` / `make run` / `make clean` — needs `clang` on `PATH`. Output: `bin/PROJECT_NAME`.
- TU model: same as `hm_mt` — every real hm_core `.c` file under `src/_hm_core/{base,os,ext,log,tui,http,linux/base}` compiles as its own TU (see `Makefile`'s `CORE_SRCS`), same for `.c` files directly under `src/`.
- Flags: `-D_GNU_SOURCE -DBUILD_CONSOLE_INTERFACE=1 -DBUILD_MULTI_TU=1`.

## raylib is not part of hm_core's GUI stack

This app drives its own window and render loop directly through raylib — it does **not** use hm_core's own `draw/`/`render/`/`ui/`/`window_manager/` layers (those stay uncompiled here; `OS_FEATURE_GRAPHICAL` is never defined, so `wm_init`/`fp_init`/`r_init`/`fnt_init` never run). Only `base/os/ext/log` are borrowed from hm_core. If you want hm_core's own immediate-mode UI stack instead of raylib, that's a different (currently unported-to-Linux) scaffold flavor — see `_hm_core_mt`'s README "What's missing".

## Vendor lib (`vendor/`)

- `vendor/raylib/{include,lib}` is **committed to git** — a fresh clone builds with no extra setup beyond `clang`/GL/X11 runtime libs already on the system.
- `vendor/build_vendor.sh` rebuilds it from source (raylib 6.0, `PLATFORM_DESKTOP`, static) — run it again to bump versions. It clones into a scratch `vendor/_build_tmp/` and deletes it when done; nothing but the built `.a`/headers persists.
- Unlike `hm_mt_cimgui` (separate cimgui + GLFW vendor libs), raylib bundles its own GLFW-equivalent (`rglfw`) and builds it internally as part of `libraylib.a` — there's only one vendor lib here.
- Built X11-only (no `PLATFORM_DESKTOP_WAYLAND` support in raylib's Makefile the way GLFW itself has it) — runs fine under XWayland on Wayland sessions.

## raylib / hm_core conflict fix

Unlike the Windows scaffold, there's no `<windows.h>` here, so there's no `NOGDI`/`CloseWindow`-renaming dance — that entire section of the Windows `hm_mt_raylib` CLAUDE.md doesn't apply on Linux. The only real clash, checked directly against hm_core's macro table and raylib/raymath's declared functions, is:

```c
#include "inc.h"
#undef Clamp        // hm_core's 3-arg Clamp(a,x,b) macro mangles raymath's Clamp(float,float,float)
#include "raylib.h"
#include "raymath.h"
```

`Clamp` is hm_core's own macro (`base/base_core.h`), not a platform-specific one, so this undef is needed even though the Win32 header conflicts are gone. If you add a new `.c` file that touches both hm_core and raylib, repeat this pattern at its top.

## Entry contract

- Define `internal void entry_point(CmdLine *cmdline)` — never `main()` (the base layer owns it: `src/_hm_core/linux/base/linux_base.c`'s `main()` → `main_thread_base_entry_point` → `entry_point`). raylib runs its own `while (!WindowShouldClose())` loop inside `entry_point`; there's no separate raylib entry point.

## Conventions for this flavor

- **Vectors**: use raylib's `Vector2`/`Vector3` + `raymath.h` for anything touching raylib calls (positions, velocities, drawing) — not hm_core's `Vec2F32`. Same layout, different C type; mixing them just means casting at every call site. Reach for `Vec2F32`/`v2f32`/etc. only for logic that never crosses into a raylib call.
- **Delta time**: `GetFrameTime()` (raylib paces the loop itself via `SetTargetFPS`) — not an hm_core/`os/` timer.
- **Per-frame temp allocation**: one `scratch_begin`/`scratch_end` pair per frame, opened before `BeginDrawing()` and closed after `EndDrawing()` — not per draw call (see `src/main.c`'s HUD string). `src/main_stub.c` — what `entry_point` starts as in a fresh project — has no scratch or per-frame strings at all; this is what to add before you need one.
- **Multiple moving objects** (e.g. more than one ball): `DA(Ball)` from `ext/ext_array.h`, not a fixed-size C array sized by guesswork — see hm_core's CLAUDE.md "Collection idiom".

## Gotchas

- New threads need `tctx_alloc()`/`tctx_select()` before arenas or scratch.
- This scaffold copies the core in from `$HMCOREMT_ROOT` at project-creation time (not referenced live like `--use-env` projects) — pulling in upstream core changes means re-running `new-cproject` (or manually re-copying), not just rebuilding.
