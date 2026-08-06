# PROJECT_NAME

Console app on hm_core (raddbg-derived C library), **true multi-TU fork**, Linux port. Library conventions, types, memory/string APIs, naming, and hard rules:

@src/_hm_core/CLAUDE.md

## Build & run

- `make` (release) / `make debug` / `make run` / `make clean` — needs `clang` on `PATH`. Output: `bin/PROJECT_NAME`.
- TU model: **no aggregate library TU**. Every real `.c` file under `src/_hm_core/{base,os,ext,log,tui,http,linux/base}` is compiled directly as its own TU (see `Makefile`'s `CORE_SRCS`), same as every `.c` directly under `src/` for your own project code. Shared declarations go in `src/inc.h` (which includes `hm_core.h`).
- Flags already set by the `Makefile`: `-D_GNU_SOURCE` (pthread rwlock/barrier need it), `-DBUILD_CONSOLE_INTERFACE=1 -DBUILD_MULTI_TU=1` (the multi-TU flag is required on every TU now, not optional).
- Because every file is its own TU, clangd/LSP works correctly when editing files under `src/_hm_core/` directly — this is the whole point of this flavor over a unity build.
- **Incremental builds**: real `make` incrementality via clang's `-MMD -MP`, which emits a `.d` dependency sidecar per object (mirrored under `obj/<release|debug>/` alongside the `.o`) — editing a shared header under `src/_hm_core/` correctly triggers a rebuild of just the TUs that include it. No hand-rolled dependency tracking needed (unlike the Windows scaffold, which has to parse `cl /showIncludes` output for this).
- `os/os_clipboard.c`, `os_console.c`, `os_env.c` are the **Windows** implementations — the Linux build compiles their `*_linux.c` siblings instead (already wired in `Makefile`). `os_registry.c` has no Linux equivalent and is dropped (there's no Windows registry to read).

## Entry contract

- Define `internal void entry_point(CmdLine *cmdline)` — never `main()` (the base layer owns it: `src/_hm_core/linux/base/linux_base.c`'s `main()` → `main_thread_base_entry_point` → `entry_point`).
- Args: `cmd_line_string(cmdline, str8_lit("name"))`, `cmd_line_has_flag(cmdline, str8_lit("verbose"))`.

## What this flavor gives you

- Console core matching today's `hm_core.h` surface: arenas/scratch, String8, threads, files, processes, http (stub on Linux — see `src/_hm_core/http/http_stub.c`), ext (ini/json/toml/print/map/array), os extras (clipboard/console/env — no registry on Linux), `lg_*` logging, `tui/` (terminal UI).
- `print`/`println` support `%S` for String8 (forked stb_sprintf).
- No GUI layers (draw/render/ui/font_provider/font_cache/window_manager/gui_shell/ui_ext) — GUI scaffolds aren't ported to Linux yet.

## Gotchas

- New threads need `tctx_alloc()`/`tctx_select()` before arenas or scratch.
- `Temp scratch = scratch_begin(0, 0)` … `scratch_end(scratch)` — pass conflicting arenas as args when returning allocations.
- This scaffold copies the core in from `$HMCOREMT_ROOT` at project-creation time (not referenced live like `--use-env` projects) — pulling in upstream core changes means re-running `new-cproject` (or manually re-copying), not just rebuilding.
