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
- `hm_mt_cimgui/` — cimgui (Dear ImGui) + GLFW + OpenGL3 GUI scaffold. Drives
  its own window/render loop directly, borrowing only hm_core's
  `base`/`os`/`ext`/`log` layers — does not use hm_core's own
  `draw`/`render`/`ui`/`window_manager` stack (still unported, see "Not
  ported yet" below). `vendor/cimgui`, `vendor/glfw` are committed static
  libs + headers, built via `vendor/build_vendor.sh` (self-cleaning —
  clones GLFW+cimgui source into a scratch dir and deletes it after
  building).
- `new-cproject.sh` — the project generator; also installable as
  `~/.bash_aliases` (see `SETUP.md`).
- `new-cproject.fish`, `cproj.fish`, `cj.fish`, `update-clangd.fish`,
  `_hmcoremt_write_clangd.fish` — fish-native port of the same generator
  (plus its `update-clangd` companion), one function per file (fish
  autoload requirement). Behavior is identical to the bash version; install
  by copying into `~/.config/fish/functions/` (see `SETUP.md`) — no
  sourcing step needed, and no function-vs-script workaround required since
  fish functions already run in the caller's shell.
- `SETUP.md` — fresh-machine setup instructions.

Each scaffold directory has: `Makefile`, `.clang-format`, `.gitignore`,
`.gitattributes`, `CLAUDE.md` (project-root template, patched with the real
project name at creation time), `resources/` (placeholder, mirrors the
Windows layout — unused on Linux so far), `src/{inc.h, main.c, main_stub.c,
_vendor/}`. No `.clangd` is checked in — see step 5 below, it's generated
fresh every time, never templated.

## What `new-cproject` does (mirrors Windows' `New-CProject`)

```
new-cproject <hm_mt|hm_mt_tui|hm_mt_cimgui> <name> [--use-env] [--demo]
new-cproject --types   # list active types, one per line, and exit
```

1. Validates `<type>` — only `hm_mt`/`hm_mt_tui`/`hm_mt_cimgui` exist on
   Linux right now; anything from the Windows type list still missing here
   (`hm_mt_gui`, `hm_mt_raylib`, `std`, `std_cimgui`) errors clearly rather
   than silently doing the wrong thing.
2. `cp -r $PROJECTS/_scaffolds_mt_linux/$TYPE ./$NAME` — for `hm_mt_cimgui`
   this includes `vendor/` (cimgui+GLFW), which is always copied in
   regardless of `--use-env` (it's the scaffold's own vendored dependency,
   not hm_core, so the live-vs-copy choice doesn't apply to it).
3. Either copies `$HMCOREMT_ROOT/src` into `$NAME/src/_hm_core/` (default),
   or (`--use-env`) rewrites the copied `Makefile`'s `CORE :=` line to point
   straight at `$HMCOREMT_ROOT/src` — no copy, so upstream core changes just
   need a rebuild, not a re-run.
4. Patches `PROJECT_NAME` into `Makefile`/`CLAUDE.md`, and picks
   `main.c` (demo, `--demo`) vs. `main_stub.c` renamed to `main.c` (minimal,
   default) as the entry point — same "Demo vs minimal" logic as Windows.
5. Writes `.clangd` from scratch (via the shared `_hmcoremt_write_clangd`
   helper — bash function in `new-cproject.sh`, fish function in its own
   autoloaded file) — copied-in projects get a relative core include path
   (`src/_hm_core`, stable across moves since it travels with the project),
   `--use-env` projects get an absolute `$HMCOREMT_ROOT/src` path (inherently
   external to the project, so it can't be relative). `.clangd` is
   `.gitignore`d in every scaffold on purpose — a `--use-env` project's
   absolute path is only valid on the machine it was created on; see
   `update-clangd` below, the port of Windows' `Update-ClangD`. When
   `vendor/cimgui` exists in the copied template (`hm_mt_cimgui`),
   `_hmcoremt_write_clangd` also gets `vendor/cimgui/include`,
   `vendor/glfw/include` appended — always relative, since `vendor/` is
   local to the project either way.
6. `git init -b main && git add -A && git commit`, then `cd`s into the new
   project directory.

### Resyncing `.clangd` after a move — `update-clangd`

Windows has a separate `Update-ClangD`/`gen_compile_commands.ps1` step for
this; the Linux port is the standalone `update-clangd` command (bash
function in `new-cproject.sh`, fish function in `update-clangd.fish`). Run
it from inside an existing generated project:

- Copied-in projects: no-op in practice — `.clangd`'s paths are already
  relative, so nothing is actually stale, but it's harmless to re-run.
- `--use-env` projects: rewrites `.clangd`'s core include line against the
  *current* `$HMCOREMT_ROOT` — needed if the project (or `$HMCOREMT_ROOT`
  itself) moved to a different path or machine since creation, since the
  old absolute path silently stops resolving otherwise (clangd degrades
  quietly — no hard error, headers just stop resolving).

It detects which mode a project is in by reading the `Makefile`'s
`CORE :=` line, so no extra state/flag file is needed.

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
- Warning suppressions (`CFLAGS` in `hm_mt`/`hm_mt_tui`'s `Makefile`) are
  cross-checked against `_scaffolds_mt/hm_mt/build.bat`'s `/wd` list, not
  guessed: `-Wno-unused-variable`/`-Wno-unused-but-set-variable`/
  `-Wno-unused-parameter` are a direct match for Windows' `/wd4101`/
  `/wd4189`/`/wd4100`. `-Wno-missing-braces`/`-Wno-initializer-overrides`
  have no MSVC `/W3` equivalent at all — hm_core's nested-struct-literal and
  `arena_alloc(...)`-style designated-initializer-override idioms are
  Clang-only pedantic warnings that fire hundreds of times per build for
  patterns MSVC doesn't diagnose. `-Wno-unused-value` covers the
  `ProfScope`/`DeferLoop` macro (`base_profile.h`/`base_core.h`) — with no
  profiling backend configured, `ProfBeginDynamic(...)` expands to a bare
  `(0)`, and Clang flags the resulting comma-operator no-op; genuinely not a
  bug (verified by reading the macro, not guessed), just not in Windows'
  `/wd` list either — no MSVC diagnostic exists for this pattern. As of
  2026-08-11, `make clean && make` on a full `hm_mt` build produces **0
  warnings**. The one warning that was a real (if trivial, harmless) bug —
  `-Wincompatible-pointer-types-discards-qualifiers` in
  `linux/base/linux_base.c:1428` — was fixed at the source via a one-line
  cast, not suppressed; see `_hm_core_mt/VENDORING.md` item 18.
- `ext_keybind.c` is excluded (needs `window_manager/`, GUI-only — same as
  Windows' plain console `hm_mt` build).

## Not ported yet (Phase 2 — GUI)

`hm_mt_gui` (hm_core's own native `draw`/`render`/`ui`/`window_manager`
stack) and `hm_mt_raylib` don't exist here. `hm_mt_cimgui` **is** done (see
above) — it sidesteps this gap entirely rather than closing it, since
cimgui+GLFW+OpenGL3 drive their own window/render loop and never touch
`render`/`window_manager`. `hm_mt_gui` still needs (in `_hm_core_mt`): the
same self-include fix applied to
`linux/window_manager/linux_window_manager.c`; X11/GL dev packages
(`libx11-dev libgl1-mesa-dev libxext-dev libxrender-dev libfreetype-dev
libfontconfig1-dev`). `hm_mt_raylib` needs a new Linux vendor build of
raylib (static) — doesn't exist yet, only the Windows `.lib` does. WSLg is
confirmed available (`DISPLAY`/`WAYLAND_DISPLAY` set) for whenever either
happens.
