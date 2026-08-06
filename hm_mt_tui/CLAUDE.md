# PROJECT_NAME

Terminal-UI (TUI) console app on hm_core (raddbg-derived C library), **true multi-TU fork**, Linux port. Library conventions, types, memory/string APIs, naming, and hard rules:

@src/_hm_core/CLAUDE.md

## Build & run

- `make` (release) / `make debug` / `make run` / `make clean` — needs `clang` on `PATH`. Output: `bin/PROJECT_NAME`.
- TU model: **no aggregate library TU**. Every real `.c` file under `src/_hm_core/{base,os,ext,log,tui,http,linux/base}` is compiled directly as its own TU (see `Makefile`'s `CORE_SRCS`), same as every `.c` directly under `src/` for your own project code. Shared declarations go in `src/inc.h` (which includes `hm_core.h`).
- Flags already set by the `Makefile`: `-D_GNU_SOURCE` (pthread rwlock/barrier need it), `-DBUILD_CONSOLE_INTERFACE=1 -DBUILD_MULTI_TU=1` (the multi-TU flag is required on every TU now, not optional).
- Because every file is its own TU, clangd/LSP works correctly when editing files under `src/_hm_core/` directly — this is the whole point of this flavor over a unity build.
- **Incremental builds**: real `make` incrementality via clang's `-MMD -MP`, which emits a `.d` dependency sidecar per object (mirrored under `obj/<release|debug>/` alongside the `.o`) — editing a shared header under `src/_hm_core/` correctly triggers a rebuild of just the TUs that include it. No hand-rolled dependency tracking needed.
- The `os/os_console_linux.c` backend (termios raw mode + poll, ANSI/SGR mouse, SIGWINCH resize) is what the `tui/` layer sits on — it's already what `tui_core.c` was written against, no OS-specific code lives in `tui/` itself.

## Entry contract

- Define `internal void entry_point(CmdLine *cmdline)` — never `main()` (the base layer owns it: `src/_hm_core/linux/base/linux_base.c`'s `main()` → `main_thread_base_entry_point` → `entry_point`).

## The tui/ layer (src/_hm_core/tui/tui_core.h)

Double-buffered cell grid over the raw-mode console; each frame you redraw everything, `tui_frame_end` diffs against what's on screen and emits minimal VT sequences.

```c
tui_init();                                          // raw mode + alt screen
for(B32 quit = 0; !quit;)
{
  Temp scratch = scratch_begin(0, 0);
  TUI_EventList events = tui_frame_begin(scratch.arena, 33);  // 33ms timeout
  for(TUI_Event *e = events.first; e != 0; e = e->next) { ... }
  tui_clear(tui_style(0xd8dee9, 0x16181c, 0));       // fg, bg = 0xRRGGBB, attrs
  tui_text(x, y, str8_lit("hi"), style);             // also: tui_put/fill/hline/vline/box
  tui_frame_end();
  scratch_end(scratch);
}
tui_shutdown();                                      // ALWAYS: restores the terminal
```

- Events: `TUI_EventKind_Key` (`e->key` = `OS_KEY_*` from os/os_console.h: OS_KEY_ESC/UP/DOWN/ENTER/F1..), `_Text` (printable, `e->key` = codepoint), `_Resize` (buffers already resized), `_MouseDown/Drag/Up/Move` (`e->mouse_x/y`, 0-based cells), `_Wheel` (`e->key` = ±1).
- Styles: `TUI_ColorDefault` keeps the terminal's own color; attrs: `TUI_Attr_Bold/Dim/Italic/Underline/Reverse`.
- Coordinates are 0-based cells; out-of-bounds drawing is clipped, `tui_size()` for current w/h.

## Conventions for this flavor

- **Growing lists** (list of rows/entries/log lines you scroll or filter): `DA(T)` from `ext/ext_array.h` — not a fixed-size array sized by guesswork. See hm_core's CLAUDE.md "Collection idiom".

## Gotchas

- If the app crashes without `tui_shutdown()`, os_console's crash handler restores the terminal — but avoid relying on it.
- One codepoint per cell (no double-width handling yet).
- New threads need `tctx_alloc()`/`tctx_select()` before arenas or scratch.
- This scaffold copies the core in from `$HMCOREMT_ROOT` at project-creation time (not referenced live like `--use-env` projects) — pulling in upstream core changes means re-running `new-cproject` (or manually re-copying), not just rebuilding.
