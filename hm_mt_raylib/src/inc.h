#pragma once

// ============================================================
// inc.h — hm_core header include.
//
// hm_core.h pulls in, in order:
//   base   - raddbg-style base (types, arena, strings, math,
//            threads, files, processes, cmdline, entry point;
//            per-OS backend included automatically)
//   http   - async HTTP (Windows; stub elsewhere)
//   ext    - extras: cstr, DA(T), result, rand_*, StrBuilder,
//            HM map, Val, ini/json/toml, print
//   os     - extras: clipboard, console, env, registry (win)
//   log    - lg_* leveled sink logging
//
// raylib is NOT part of hm_core — this app drives its own window and
// render loop via raylib (see main.c), only borrowing hm_core's
// base/os/ext/log layers. hm_core's own GUI stack (draw/render/ui/
// window_manager/font_provider) is untouched and not compiled in here.
//
// NOTE: on Linux there's no <windows.h>-style header collision to guard
// against (that's a Win32-only problem — see the Windows hm_mt_raylib
// scaffold's "Win32 / raylib conflict fix"). The one real clash, hm_core's
// Clamp(a,x,b) macro vs raymath's Clamp(float,float,float) function, is
// platform-independent — main.c #undefs it after this include, before
// raylib.h/raymath.h.
// ============================================================

#include "hm_core.h"
