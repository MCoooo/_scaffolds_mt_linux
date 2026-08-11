// raylib/hm_core conflict fix — see CLAUDE.md's "raylib conflict fix"
// section. On Linux the only clash is hm_core's Clamp(a,x,b) macro vs
// raymath's Clamp(float,float,float) function.
#include "inc.h"

#undef Clamp

#include "raylib.h"
#include "raymath.h"

internal void
entry_point(CmdLine *cmdline)
{
    (void)cmdline;

    InitWindow(900, 600, "my_project");
    SetTargetFPS(60);

    while (!WindowShouldClose())
    {
        BeginDrawing();
        ClearBackground(DARKGRAY);
        EndDrawing();
    }

    CloseWindow();
}
