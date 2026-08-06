// ============================================================
// main.c — hm_core demo (mt / true multi-TU build).
//
// ENTRY-POINT CONTRACT: this app does not define main().
// See _hm_core/NOTES.md for the full call chain.
//
// Try: build.bat run
//      bin\<name>.exe --name=you --verbose
// ============================================================

#include "inc.h"
// (no inc.c — every hm_core .c file is its own TU; see build.bat's glob)

// ------------------------------------------------------------
// Worker thread for the threading demo
// ------------------------------------------------------------
typedef struct WorkerCtx WorkerCtx;
struct WorkerCtx
{
    Mutex mutex;
    U64   counter;
};

internal void
worker_entry(void *p)
{
    WorkerCtx *ctx = (WorkerCtx *)p;
    for EachIndex(i, 1000)
    {
        (void)i;
        MutexScope(ctx->mutex)
        {
            ctx->counter += 1;
        }
    }
}

// ------------------------------------------------------------
// Entry point
// ------------------------------------------------------------
internal void
entry_point(CmdLine *cmdline)
{
    Arena *arena = arena_alloc();

    // --------------------------------------------------------
    println("== command line ==");
    // --------------------------------------------------------
    {
        String8 name = cmd_line_string(cmdline, str8_lit("name"));
        if (name.size == 0) { name = str8_lit("world"); }
        B32 verbose = cmd_line_has_flag(cmdline, str8_lit("verbose"));
        print("hello, %S%s\n", name, verbose ? " (verbose)" : "");
    }

    // --------------------------------------------------------
    println("\n== arenas & scratch ==");
    // --------------------------------------------------------
    {
        U64 pos_before = arena_pos(arena);
        U8 *block = push_array(arena, U8, 1024);          // zeroed
        U8 *fast  = push_array_no_zero(arena, U8, 1024);  // not zeroed
        (void)block; (void)fast;
        print("arena pos: %llu -> %llu\n", pos_before, arena_pos(arena));

        Temp temp = temp_begin(arena);
        push_array(arena, U8, 4096);
        temp_end(temp);  // rewinds the 4096
        print("after temp rewind: %llu\n", arena_pos(arena));

        // thread-context scratch — no arena needed at the call site
        Temp scratch = scratch_begin(0, 0);
        String8 s = push_str8f(scratch.arena, "scratch says %d", 42);
        print("%S\n", s);
        scratch_end(scratch);
    }

    // --------------------------------------------------------
    println("\n== strings ==");
    // --------------------------------------------------------
    {
        String8 a = str8_lit("  Hello, Handmade!  ");
        String8 trimmed = str8_skip_chop_whitespace(a);
        print("trimmed:   '%S'\n", trimmed);

        String8 joined2 = str8_cat(arena, str8_lit("foo"), str8_lit("bar"));
        print("cat:       %S\n", joined2);

        B32 eq  = str8_match(str8_lit("abc"), str8_lit("ABC"), 0);
        B32 eqi = str8_match(str8_lit("abc"), str8_lit("ABC"), StringMatchFlag_CaseInsensitive);
        print("match:     exact=%d nocase=%d\n", eq, eqi);

        // formatting goes through the stb_sprintf fork: %S = String8
        String8 fmt = push_str8f(arena, "[%S|%05d|%.2f]", trimmed, 42, 3.14159);
        print("fmt:       %S\n", fmt);
    }

    // --------------------------------------------------------
    println("\n== string lists (split / join) ==");
    // --------------------------------------------------------
    {
        Temp scratch = scratch_begin(0, 0);
        String8 csv = str8_lit("alpha,beta,gamma");
        String8List parts = str8_split_by_string_chars(scratch.arena, csv, str8_lit(","), 0);
        print("split %S -> %llu parts:", csv, parts.node_count);
        for (String8Node *n = parts.first; n != 0; n = n->next)
            print(" '%S'", n->string);
        print("\n");

        StringJoin join = { str8_lit("("), str8_lit(" + "), str8_lit(")") };
        String8 joined = str8_list_join(scratch.arena, &parts, &join);
        print("join: %S\n", joined);
        scratch_end(scratch);
    }

    // --------------------------------------------------------
    println("\n== core macros ==");
    // --------------------------------------------------------
    {
        print("Min/Max/Clamp: %d %d %d\n", Min(3, 7), Max(3, 7), Clamp(0, 99, 10));

        int evens[] = {2, 4, 6, 8};
        int sum = 0;
        for EachElement(i, evens) { sum += evens[i]; }
        print("EachElement sum: %d\n", sum);

        // singly-linked queue via SLL macros
        typedef struct Node Node; struct Node { Node *next; int v; };
        Node *first = 0, *last = 0;
        Temp scratch = scratch_begin(0, 0);
        for EachIndex(i, 3)
        {
            Node *n = push_array(scratch.arena, Node, 1);
            n->v = (int)i * 10;
            SLLQueuePush(first, last, n);
        }
        print("SLL queue:");
        for EachNode(it, Node, first) { print(" %d", it->v); }
        print("\n");
        scratch_end(scratch);
    }

    // --------------------------------------------------------
    println("\n== dynamic array / hash map / string builder ==");
    // --------------------------------------------------------
    {
        DA(int) nums = {0};
        da_push(&nums, 10);
        da_push(&nums, 20);
        da_push(&nums, 30);
        da_remove_swap(&nums, 0);
        print("da: len=%llu [%d, %d]\n", nums.len, nums.data[0], nums.data[1]);
        da_free(&nums);

        HM m = {0};
        hm_put(&m, str8_lit("port"),  (void *)(uintptr_t)8080);
        hm_put(&m, str8_lit("debug"), (void *)(uintptr_t)1);
        print("hm: port=%d has(debug)=%d\n",
              (int)(uintptr_t)hm_get(&m, str8_lit("port")),
              hm_has(&m, str8_lit("debug")));
        hm_free(&m);

        StrBuilder b = sb_make(arena);
        sb_append(&b, str8_lit("x = "));
        sb_appendf(&b, "%d, y = %d", 1, 2);
        print("sb: %S\n", sb_finish(&b));
    }

    // --------------------------------------------------------
    println("\n== json / toml / ini ==");
    // --------------------------------------------------------
    {
        Temp scratch = scratch_begin(0, 0);

        Json_Result jr = json_parse(scratch.arena,
            str8_lit("{\"name\": \"hm\", \"vals\": [1, 2.5, true]}"));
        if (result_ok(jr))
            print("json: name=%S vals[1]=%f\n",
                  val_as_str(val_obj_get(jr.root, str8_lit("name"))),
                  val_as_flt(val_arr_get(val_obj_get(jr.root, str8_lit("vals")), 1)));

        Toml_Result tr = toml_parse(scratch.arena,
            str8_lit("[server]\nhost = \"localhost\"\nport = 0x1F90\n"));
        if (result_ok(tr))
        {
            Val *server = val_obj_get(tr.root, str8_lit("server"));
            print("toml: %S:%lld\n",
                  val_as_str(val_obj_get(server, str8_lit("host"))),
                  val_as_int(val_obj_get(server, str8_lit("port"))));
        }

        Ini_Result ir = ini_parse(scratch.arena,
            str8_lit("[paths]\nhome = c:\\dev  ; comment\n"));
        if (result_ok(ir))
            print("ini: home=%S\n", ini_get(ir.ini, str8_lit("paths"), str8_lit("home")));

        scratch_end(scratch);
    }

    // --------------------------------------------------------
    println("\n== random ==");
    // --------------------------------------------------------
    {
        Rand r = rand_make_time();
        print("u32=%u  [0,100)=%lld  f32=%f  bool=%d\n",
              rand_u32(&r), rand_range(&r, 0, 100), rand_f32(&r), rand_bool(&r));
    }

    // --------------------------------------------------------
    println("\n== files ==");
    // --------------------------------------------------------
    {
        Temp scratch = scratch_begin(0, 0);
        String8 path = str8_lit("hm_demo_tmp.txt");
        write_data_to_file_path(path, str8_lit("written by hm_core demo\n"));
        append_data_to_file_path(path, str8_lit("appended line\n"));

        String8 contents = data_from_file_path(scratch.arena, path);
        print("read back %llu bytes\n", contents.size);

        U64 entry_count = 0;
        FileIter *it = file_iter_begin(scratch.arena, str8_lit("."), 0);
        for (FileInfo info = {0}; file_iter_next(scratch.arena, it, &info);)
            entry_count += 1;
        file_iter_end(it);
        print("entries in cwd: %llu\n", entry_count);

        delete_file_at_path(path);
        print("tmp file exists after delete: %d\n", file_path_exists(path));
        scratch_end(scratch);
    }

    // --------------------------------------------------------
    println("\n== time ==");
    // --------------------------------------------------------
    {
        U64 t0 = now_time_us();
        DateTime now = now_time_universal();
        U64 t1 = now_time_us();
        // note: DateTime.mon is 0-based; .day is 1-based (win32 backend)
        print("utc: %04u-%02u-%02u %02u:%02u:%02u (queried in %llu us)\n",
              (U32)now.year, (U32)now.mon + 1, (U32)now.day,
              (U32)now.hour, (U32)now.min, (U32)now.sec, t1 - t0);
    }

    // --------------------------------------------------------
    println("\n== threads ==");
    // --------------------------------------------------------
    {
        WorkerCtx ctx = {0};
        ctx.mutex = mutex_alloc();

        Thread threads[4];
        for EachElement(i, threads) { threads[i] = thread_launch(worker_entry, &ctx); }
        for EachElement(i, threads) { thread_join(threads[i], max_U64); }

        print("4 threads x 1000 increments = %llu\n", ctx.counter);
        mutex_release(ctx.mutex);
    }

    // --------------------------------------------------------
    println("\n== logging (lg) ==");
    // --------------------------------------------------------
    {
        lg_init(LG_Level_Debug);
        lg_add_stdout_sink();
        lg_debug("debug message");
        lg_info("server started on port %d", 8080);
        lg_warn("low memory: %S", str8_lit("simulated"));
        lg_shutdown();
    }

    // --------------------------------------------------------
    println("\n== os extras ==");
    // --------------------------------------------------------
    {
        Temp scratch = scratch_begin(0, 0);

        String8 path_var = os_env_get(scratch.arena, str8_lit("PATH"));
        print("PATH is %llu bytes\n", path_var.size);
        os_setenv(str8_lit("HM_DEMO"), str8_lit("1"));
        print("HM_DEMO=%S\n", os_env_get(scratch.arena, str8_lit("HM_DEMO")));

        os_clipboard_set(str8_lit("hm_core was here"));
        String8 clip = os_clipboard_get(scratch.arena);
        print("clipboard: %S\n", clip);

#if OS_WINDOWS
        String8 product = os_reg_read_str(scratch.arena, OS_RegRoot_LocalMachine,
            str8_lit("SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion"),
            str8_lit("ProductName"));
        print("registry ProductName: %S\n", product);
#endif

        scratch_end(scratch);
    }

    arena_release(arena);
    println("\ndone.");
}
