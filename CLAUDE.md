# _scaffolds_mt_linux

Native Linux/WSL2 project scaffolds for [`hm_core_mt`](https://github.com/MCoooo/hm_core_mt)
(a raddbg-derived, true-multi-TU C library). This is the Linux counterpart
to the Windows `_scaffolds_mt` repo (PowerShell `New-CProject` + `build.bat`)
— **not a clone or fork of it**. They're deliberately separate repos: the
Windows and Linux versions of a scaffold type share a directory name
(`hm_mt/`, `hm_mt_tui/`) but not a build system (`build.bat`+
`build_incremental.ps1`+`gen_compile_commands.ps1` vs. a plain `Makefile`),
so cloning one to make the other meant deleting the other OS's build files
in what git saw as "the same repo" — exactly the kind of accidental-shared-history
mistake this split avoids. If you're looking for the Windows scaffolds,
they're in the sibling `_scaffolds_mt` repo; this repo doesn't reference or
depend on it in any way.

`_hm_core_mt` **is** genuinely shared between the two OSes (one repo, one
history) — this repo's scaffolds consume it via the `HMCOREMT_ROOT` env var,
either copying `src/` in or referencing it live (`--use-env`).

See `SETUP.md` for how to get this working on a fresh machine, and
`new-cproject.sh` for the actual project-generator (a bash function, not a
standalone script — see "Why a function, not a script" below).

## Repo layout

- `hm_mt/` — console scaffold: full `hm_core.h` surface (arenas, strings,
  threads, files, http, json/toml/ini, `tui/`, os extras) minus GUI layers.
- `hm_mt_tui/` — same core, but `src/main.c` is a TUI app (double-buffered
  cell grid over raw-mode terminal) instead of a plain console demo.
- `new-cproject.sh` — the project generator; also installable as
  `~/.bash_aliases` (see `SETUP.md`).
- `SETUP.md` — fresh-machine setup instructions.

Each scaffold directory has: `Makefile`, `.clangd`, `.clang-format`,
`.gitignore`, `.gitattributes`, `CLAUDE.md` (project-root template, patched
with the real project name at creation time), `resources/` (placeholder,
mirrors the Windows layout — unused on Linux so far), `src/{inc.h, main.c,
main_stub.c, _vendor/}`.

## What `new-cproject` does (mirrors Windows' `New-CProject`)

```
new-cproject <hm_mt|hm_mt_tui> <name> [--use-env] [--demo]
```

1. Validates `<type>` — only `hm_mt`/`hm_mt_tui` exist on Linux right now;
   anything from the Windows type list (`hm_mt_gui`, `hm_mt_cimgui`,
   `hm_mt_raylib`, `std`, `std_cimgui`) errors clearly rather than silently
   doing the wrong thing.
2. `cp -r $PROJECTS/_scaffolds_mt_linux/$TYPE ./$NAME`.
3. Either copies `$HMCOREMT_ROOT/src` into `$NAME/src/_hm_core/` (default),
   or (`--use-env`) rewrites the copied `Makefile`'s `CORE :=` line and
   `.clangd`'s include path to point straight at `$HMCOREMT_ROOT/src` — no
   copy, so upstream core changes just need a rebuild, not a re-run.
4. Patches `PROJECT_NAME` into `Makefile`/`CLAUDE.md`, and picks
   `main.c` (demo, `--demo`) vs. `main_stub.c` renamed to `main.c` (minimal,
   default) as the entry point — same "Demo vs minimal" logic as Windows.
5. Regenerates `.clangd` with absolute paths (Windows does this via
   `Update-ClangD`/`gen_compile_commands.ps1`; here it's inline `sed`).
6. `git init -b main && git add -A && git commit`, then `cd`s into the new
   project directory.

### Why a function, not a script

PowerShell's `New-CProject` ends with `Set-Location $dest`, leaving you
inside the new project. A bash *script* can't do that — a subprocess's `cd`
never affects the calling shell, so `new-cproject` is a **function**,
sourced into your interactive shell (via `~/.bash_aliases`), not something
you'd `chmod +x` and drop on `PATH`. Don't "fix" this into a standalone
script without also solving that, or you'll silently lose the
cd-into-new-project behavior.

## The two `hm_core_mt` bugfixes this required

Bringing up these scaffolds needed two small patches to `_hm_core_mt`
itself (documented there in `VENDORING.md` items 1 and 17, both confined to
`src/linux/base/`, both proven not to affect Windows since Windows never
compiles that directory):

1. `src/linux/base/linux_base.c` was missing its self-`#include
   "base/base_inc.h"` — every other true-multi-TU `.c` file has this
   (compare `win32_base.c`'s first line); without it the file only worked
   when something else included it first, i.e. never, under this build
   model.
2. `src/linux/base/linux_base.h`'s `lnx_safe_call_chain` was declared
   `thread_static` without `global` (`static`), giving it external linkage
   and causing "multiple definition" link errors across every TU that
   includes the header.

Both are applied in both the WSL-native `_hm_core_mt` clone and the Windows
checkout (kept in sync manually — same repo, same history, just two working
copies on two filesystems).

## Build model (see `_hm_core_mt/CLAUDE.md` for the library's own rules)

- `clang` + a plain `Makefile` per project — no wrapper script.
  Incrementality comes from clang's `-MMD -MP` (auto-generated `.d`
  dependency sidecars under `obj/<release|debug>/`), which is what Windows
  had to hand-roll `build_incremental.ps1` (`cl /showIncludes` parsing) to
  get. Verified: editing a shared header under `src/_hm_core/` only
  recompiles the TUs that actually include it.
- `-D_GNU_SOURCE` is required (glibc hides `pthread_rwlock_t`/
  `pthread_barrier_t` without it).
- `os/os_clipboard.c`, `os_console.c`, `os_env.c` in `_hm_core_mt` are the
  **Windows** implementations — the Makefiles compile their `*_linux.c`
  siblings instead. `os_registry.c` has no Linux equivalent (dropped;
  Windows-only feature).
- `ext_keybind.c` is excluded (needs `window_manager/`, GUI-only — same as
  Windows' plain console `hm_mt` build).

## Not ported yet (Phase 2 — GUI)

`hm_mt_gui`, `hm_mt_cimgui`, `hm_mt_raylib` don't exist here. Needs (in
`_hm_core_mt`): the same self-include fix applied to
`linux/window_manager/linux_window_manager.c`; X11/GL dev packages
(`libx11-dev libgl1-mesa-dev libxext-dev libxrender-dev libfreetype-dev
libfontconfig1-dev`); new Linux vendor builds of cimgui (GLFW+OpenGL3
backend, static) and raylib (static) — neither exists yet, only Windows
`.lib`s do. WSLg is confirmed available (`DISPLAY`/`WAYLAND_DISPLAY` set)
for whenever this happens.
