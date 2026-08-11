// ============================================================
// main.c — hm_core + raylib 6.x (static) demo, Linux port.
//
// ENTRY-POINT CONTRACT: this app does not define main().
// See src/_hm_core/CLAUDE.md for the full call chain.
//
// raylib drives its own window + render loop directly — it is NOT part of
// hm_core's own GUI stack (draw/render/ui/window_manager), which stays
// uncompiled here. Only base/os/ext/log are borrowed.
//
// raylib/hm_core conflict fix: the only clash on Linux (no <windows.h>
// here, unlike the Windows scaffold) is hm_core's Clamp(a,x,b) macro
// mangling raymath's Clamp(float,float,float) function — undef it after
// inc.h, before raylib.h/raymath.h. See inc.h for the full rationale.
// ============================================================

#include "inc.h"

#undef Clamp

#include "raylib.h"
#include "raymath.h"

// ============================================================
// Demo: bouncing ball + mouse cursor + keyboard input
// ============================================================

#define SCREEN_W 900
#define SCREEN_H 600

typedef struct Ball Ball;
struct Ball
{
    Vector2 pos;
    Vector2 vel;
    float   radius;
    Color   color;
};

internal Ball
ball_make(int screen_w, int screen_h)
{
    Ball b;
    b.pos    = (Vector2){ (float)screen_w * 0.5f, (float)screen_h * 0.5f };
    b.vel    = (Vector2){ 220.f, 160.f };
    b.radius = 24.f;
    b.color  = RED;
    return b;
}

internal void
ball_update(Ball *b, float dt, int screen_w, int screen_h)
{
    b->pos.x += b->vel.x * dt;
    b->pos.y += b->vel.y * dt;

    if (b->pos.x - b->radius < 0)
    {
        b->pos.x = b->radius;
        b->vel.x = -b->vel.x;
    }
    if (b->pos.x + b->radius > (float)screen_w)
    {
        b->pos.x = (float)screen_w - b->radius;
        b->vel.x = -b->vel.x;
    }
    if (b->pos.y - b->radius < 0)
    {
        b->pos.y = b->radius;
        b->vel.y = -b->vel.y;
    }
    if (b->pos.y + b->radius > (float)screen_h)
    {
        b->pos.y = (float)screen_h - b->radius;
        b->vel.y = -b->vel.y;
    }
}

internal void
entry_point(CmdLine *cmdline)
{
    (void)cmdline;

    InitWindow(SCREEN_W, SCREEN_H, "hm_core + raylib -- bouncing ball");
    SetTargetFPS(60);

    Ball ball = ball_make(SCREEN_W, SCREEN_H);

    // Palette cycled with 1/2/3/4/5
    Color palette[] = { RED, SKYBLUE, LIME, ORANGE, VIOLET };
    int   pal_count = (int)ArrayCount(palette);
    int   pal_idx   = 0;

    while (!WindowShouldClose())
    {
        // -- update --
        float dt = GetFrameTime();
        ball_update(&ball, dt, SCREEN_W, SCREEN_H);

        if (IsKeyPressed(KEY_ONE))   { pal_idx = 0; ball.color = palette[pal_idx]; }
        if (IsKeyPressed(KEY_TWO))   { pal_idx = 1; ball.color = palette[pal_idx]; }
        if (IsKeyPressed(KEY_THREE)) { pal_idx = 2; ball.color = palette[pal_idx]; }
        if (IsKeyPressed(KEY_FOUR))  { pal_idx = 3; ball.color = palette[pal_idx]; }
        if (IsKeyPressed(KEY_FIVE))  { pal_idx = 4; ball.color = palette[pal_idx]; }
        (void)pal_count;

        Vector2 mouse = GetMousePosition();

        // hm_core scratch for per-frame strings
        Temp scratch = scratch_begin(0, 0);

        String8 hud = push_str8f(scratch.arena,
            "fps: %d   ball: (%.0f, %.0f)   mouse: (%.0f, %.0f)   keys 1-5: color",
            GetFPS(), ball.pos.x, ball.pos.y, mouse.x, mouse.y);

        // -- draw --
        BeginDrawing();
            ClearBackground(DARKGRAY);

            // ball shadow
            DrawCircleV((Vector2){ ball.pos.x + 4, ball.pos.y + 4 },
                        ball.radius, (Color){ 0, 0, 0, 80 });
            // ball
            DrawCircleV(ball.pos, ball.radius, ball.color);
            DrawCircleLinesV(ball.pos, ball.radius, WHITE);

            // mouse crosshair
            DrawCircleLines((int)mouse.x, (int)mouse.y, 10, YELLOW);
            DrawLine((int)mouse.x - 14, (int)mouse.y,
                     (int)mouse.x + 14, (int)mouse.y, YELLOW);
            DrawLine((int)mouse.x, (int)mouse.y - 14,
                     (int)mouse.x, (int)mouse.y + 14, YELLOW);

            // HUD bar
            DrawRectangle(0, SCREEN_H - 28, SCREEN_W, 28, (Color){ 0, 0, 0, 160 });
            DrawText((const char *)hud.str, 8, SCREEN_H - 21, 14, LIGHTGRAY);

        EndDrawing();

        scratch_end(scratch);
    }

    CloseWindow();
}
