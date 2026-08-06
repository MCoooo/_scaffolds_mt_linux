// ============================================================
// main.c — hm_core TUI demo (mt / true multi-TU build).
//
// The tui/ layer gives a double-buffered cell grid over the
// raw-mode console (os/os_console): draw into the back buffer
// each frame, tui_frame_end diffs and emits minimal VT codes.
//
// ENTRY-POINT CONTRACT: this app does not define main().
// See _hm_core/NOTES.md for the full call chain.
//
// Try: build.bat run     (press Esc or q to quit)
// ============================================================

#include "inc.h"
// (no inc.c — every hm_core .c file is its own TU; see build.bat's glob)

// ------------------------------------------------------------
// Demo state
// ------------------------------------------------------------
global S32   g_selected = 0;
global B32   g_checks[3] = {1, 0, 0};
global U8    g_key_log[64];
global U64   g_key_log_size = 0;
global S32   g_mouse_x = 0;
global S32   g_mouse_y = 0;

read_only global char *g_menu_items[] =
{
    "first thing",
    "second thing",
    "third thing",
};

internal void
key_log_push(U32 codepoint)
{
    U8 utf8[8];
    U32 size = utf8_encode(utf8, codepoint);
    if (g_key_log_size + size > sizeof(g_key_log))
    {
        g_key_log_size = 0;
    }
    MemoryCopy(g_key_log + g_key_log_size, utf8, size);
    g_key_log_size += size;
}

// ------------------------------------------------------------
// Entry point
// ------------------------------------------------------------
internal void
entry_point(CmdLine *cmdline)
{
    tui_init();
    U64 start_us = now_time_us();

    for (B32 quit = 0; !quit;)
    {
        Temp scratch = scratch_begin(0, 0);

        // ----------------------------------------------------
        // input
        // ----------------------------------------------------
        TUI_EventList events = tui_frame_begin(scratch.arena, 33);
        for (TUI_Event *e = events.first; e != 0; e = e->next)
        {
            switch (e->kind)
            {
                default: break;
                case TUI_EventKind_Key:
                {
                    if (e->key == OS_KEY_ESC)  { quit = 1; }
                    if (e->key == OS_KEY_UP)   { g_selected = Max(0, g_selected - 1); }
                    if (e->key == OS_KEY_DOWN) { g_selected = Min((S32)ArrayCount(g_menu_items) - 1, g_selected + 1); }
                    if (e->key == OS_KEY_ENTER){ g_checks[g_selected] ^= 1; }
                }break;
                case TUI_EventKind_Text:
                {
                    if (e->key == 'q' || e->key == 'Q') { quit = 1; }
                    else { key_log_push((U32)e->key); }
                }break;
                case TUI_EventKind_MouseMove:
                case TUI_EventKind_MouseDrag:
                case TUI_EventKind_MouseDown:
                {
                    g_mouse_x = e->mouse_x;
                    g_mouse_y = e->mouse_y;
                }break;
            }
        }

        F64 t = (F64)(now_time_us() - start_us)/1000000.0;
        Vec2S32 size = tui_size();

        // ----------------------------------------------------
        // draw
        // ----------------------------------------------------
        TUI_Style base   = tui_style(0xd8dee9, 0x16181c, 0);
        TUI_Style weak   = tui_style(0x8b8f96, 0x16181c, 0);
        TUI_Style accent = tui_style(0x6db2ff, 0x16181c, 0);

        tui_clear(base);
        tui_box(0, 0, size.x, size.y, 1, accent);
        tui_text(2, 0, str8_lit(" hm_core tui "), tui_style(0x16181c, 0x6db2ff, TUI_Attr_Bold));

        //- status line
        tui_text(2, 2, str8f(scratch.arena, "terminal %dx%d   t %.1fs   mouse %d,%d",
                             size.x, size.y, t, g_mouse_x, g_mouse_y), base);
        tui_text(2, 3, str8_lit("arrows move, enter toggles; type to echo; Esc or q quits"), weak);

        //- selectable checkbox list
        tui_box(2, 5, 34, (S32)ArrayCount(g_menu_items) + 2, 0, tui_style(0x33373d, 0x16181c, 0));
        for EachIndex(idx, ArrayCount(g_menu_items))
        {
            B32 is_sel = ((S32)idx == g_selected);
            TUI_Style row = is_sel ? tui_style(0x16181c, 0x6db2ff, TUI_Attr_Bold) : base;
            if (is_sel)
            {
                tui_fill(3, 6 + (S32)idx, 32, 1, ' ', row);
            }
            tui_text(3, 6 + (S32)idx, str8f(scratch.arena, " [%s] %s",
                                            g_checks[idx] ? "x" : " ", g_menu_items[idx]), row);
        }

        //- animated progress bar
        {
            S32 bar_x = 2;
            S32 bar_y = 6 + (S32)ArrayCount(g_menu_items) + 3;
            S32 bar_w = Min(40, size.x - 10);
            F32 frac = 0.5f + 0.5f*sin_f32((F32)t*0.25f);
            S32 filled = (S32)(frac*(F32)bar_w);
            tui_text(bar_x, bar_y, str8_lit("["), base);
            tui_text(bar_x + 1 + bar_w, bar_y, str8f(scratch.arena, "] %3d%%", (S32)(frac*100.f)), base);
            for (S32 i = 0; i < bar_w; i += 1)
            {
                B32 on = (i < filled);
                tui_put(bar_x + 1 + i, bar_y, on ? 0x2588 : 0x2591,
                        tui_style(on ? 0x98c379 : 0x33373d, 0x16181c, 0));
            }
        }

        //- style showcase + typed-key echo
        {
            S32 y = 6 + (S32)ArrayCount(g_menu_items) + 5;
            tui_text(2, y + 0, str8_lit("bold"),      tui_style(0xffffff, 0x16181c, TUI_Attr_Bold));
            tui_text(2, y + 1, str8_lit("underline"), tui_style(0xe5c07b, 0x16181c, TUI_Attr_Underline));
            tui_text(2, y + 2, str8_lit("reverse"),   tui_style(0x61afef, 0x16181c, TUI_Attr_Reverse));
            tui_text(14, y + 1, str8f(scratch.arena, "typed: %S", str8(g_key_log, g_key_log_size)),
                     tui_style(0xc678dd, 0x16181c, 0));
        }

        tui_frame_end();
        scratch_end(scratch);
    }

    tui_shutdown();
}
