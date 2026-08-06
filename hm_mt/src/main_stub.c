#include "inc.h"

internal void
entry_point(CmdLine *cmdline)
{
    (void)cmdline;
    Arena *arena = arena_alloc();

    // ...

    arena_release(arena);
}
