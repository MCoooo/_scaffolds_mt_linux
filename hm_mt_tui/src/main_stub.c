// ============================================================
// main.c — minimal hm_core TUI starting point (mt / true multi-TU build).
//
// ENTRY-POINT CONTRACT: this app does not define main().
// See _hm_core/NOTES.md for the full call chain.
// ============================================================

#include "inc.h"

internal void
entry_point(CmdLine *cmdline)
{
    tui_init();
    for (B32 quit = 0; !quit;)
    {
        Temp scratch = scratch_begin(0, 0);
        TUI_EventList events = tui_frame_begin(scratch.arena, 33);
        for (TUI_Event *e = events.first; e != 0; e = e->next)
        {
            if (e->kind == TUI_EventKind_Key  && e->key == OS_KEY_ESC) { quit = 1; }
            if (e->kind == TUI_EventKind_Text && e->key == 'q')        { quit = 1; }
        }

        tui_clear(tui_style(0xd8dee9, 0x16181c, 0));
        tui_text(2, 1, str8_lit("hello — edit src/main.c (Esc or q quits)"),
                 tui_style(0xffffff, 0x16181c, TUI_Attr_Bold));

        tui_frame_end();
        scratch_end(scratch);
    }
    tui_shutdown();
}
