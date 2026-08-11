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
// cimgui/GLFW are NOT part of hm_core — this app drives its own window
// and render loop via GLFW+OpenGL3 (see main.c), only borrowing hm_core's
// base/os/ext/log layers. hm_core's own GUI stack (draw/render/ui/
// window_manager/font_provider) is untouched and not compiled in here.
// ============================================================

#include "hm_core.h"
