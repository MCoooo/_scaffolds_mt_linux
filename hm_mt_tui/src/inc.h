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
// ============================================================

#include "hm_core.h"
