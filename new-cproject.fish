# new-cproject.fish — fish-native port of new-cproject.sh (which itself
# ports the Windows New-CProject PowerShell function).
# Install: run setup.sh fish, or copy all .fish files to ~/.config/fish/functions/
# Fish autoloads from that directory — no sourcing step needed.

function new-cproject --description "Create a new hm_core_mt project from a Linux scaffold"
    set valid_types hm_mt hm_mt_tui hm_mt_cimgui hm_mt_raylib
    set not_yet_ported hm_mt_gui std std_cimgui

    if contains -- --help $argv
        echo "new-cproject — create a new hm_core_mt C project from a scaffold"
        echo ""
        echo "WHAT:"
        echo "  Copies a scaffold template, links or copies hm_core into it,"
        echo "  generates .clangd so clangd works out of the box, runs git init,"
        echo "  and cd's into the new project directory."
        echo ""
        echo "WHEN:"
        echo "  Whenever you start a new C project using the hm_core_mt library."
        echo ""
        echo "USAGE:"
        echo "  new-cproject <type> <name> [--use-env] [--demo]"
        echo "  new-cproject --types    list available scaffold types"
        echo "  new-cproject --help"
        echo ""
        echo "TYPES:"
        for t in $valid_types
            echo "  $t"
        end
        echo ""
        echo "OPTIONS:"
        echo "  --demo      Keep the full demo main.c (arenas, strings, threads, etc.)"
        echo "              Default is a minimal stub."
        echo "  --use-env   Reference \$HMCOREMT_ROOT live instead of copying hm_core"
        echo "              into src/_hm_core. Picks up upstream core changes on next"
        echo "              rebuild. .clangd uses an absolute path — run update-clangd"
        echo "              after cloning on a new machine or if \$HMCOREMT_ROOT moves."
        echo "              Without --use-env, hm_core is a frozen snapshot inside the"
        echo "              project; .clangd paths are relative and never go stale."
        echo ""
        echo "ALIASES: cproj, cj"
        return 0
    end

    if contains -- --types $argv
        for t in $valid_types
            echo $t
        end
        return 0
    end

    if test (count $argv) -lt 2
        echo "Usage: new-cproject <type> <name> [--use-env] [--demo]" >&2
        echo "       new-cproject --help" >&2
        echo "       new-cproject --types" >&2
        return 1
    end

    set type $argv[1]
    set name $argv[2]
    set use_env 0
    set demo 0

    for arg in $argv[3..-1]
        switch $arg
            case --use-env
                set use_env 1
            case --demo
                set demo 1
            case '*'
                echo "[!] Unknown option '$arg'." >&2
                return 1
        end
    end

    if not contains $type $valid_types
        if contains $type $not_yet_ported
            echo "[!] '$type' is not yet ported to Linux (see _hm_core_mt Phase 2 notes)." >&2
            return 1
        end
        echo "[!] Unknown project type '$type'. Valid: $valid_types" >&2
        return 1
    end

    if test -z "$PROJECTS"
        echo "[!] PROJECTS environment variable is not set." >&2
        return 1
    end
    if test -z "$HMCOREMT_ROOT"
        echo "[!] HMCOREMT_ROOT environment variable is not set." >&2
        return 1
    end
    if not test -d "$HMCOREMT_ROOT"
        echo "[!] HMCOREMT_ROOT ($HMCOREMT_ROOT) does not exist." >&2
        return 1
    end

    set scaffolds "$PROJECTS/_scaffolds_mt_linux"
    set dest "$PWD/$name"

    if test -e "$dest"
        echo "[!] '$dest' already exists." >&2
        return 1
    end
    if not test -d "$scaffolds/$type"
        echo "[!] Scaffold not found: $scaffolds/$type" >&2
        return 1
    end

    echo "Creating '$name' ($type)..."
    cp -r "$scaffolds/$type" "$dest"

    set extra_includes
    if test -d "$dest/vendor/cimgui"
        set extra_includes vendor/cimgui/include vendor/glfw/include
    else if test -d "$dest/vendor/raylib"
        set extra_includes vendor/raylib/include
    end

    if test $use_env -eq 1
        sed -i "s|^CORE := src/_hm_core|CORE := \$(HMCOREMT_ROOT)/src|" "$dest/Makefile"
        _hmcoremt_write_clangd "$dest" "$HMCOREMT_ROOT/src" $extra_includes
        if test -f "$dest/CLAUDE.md"
            sed -i "s|@src/_hm_core/CLAUDE.md|@$HMCOREMT_ROOT/CLAUDE.md|" "$dest/CLAUDE.md"
        end
        echo "[+] Wired to live HMCOREMT_ROOT ($HMCOREMT_ROOT) - no core copy"
    else
        mkdir -p "$dest/src/_hm_core"
        cp -r "$HMCOREMT_ROOT/src/." "$dest/src/_hm_core/"
        test -f "$HMCOREMT_ROOT/CLAUDE.md"; and cp "$HMCOREMT_ROOT/CLAUDE.md" "$dest/src/_hm_core/CLAUDE.md"
        # Paths relative to src/ — clangd's fallback runs from the source
        # file's directory, not the project root, so _hm_core resolves to
        # src/_hm_core correctly from that working directory.
        _hmcoremt_write_clangd "$dest" "_hm_core" $extra_includes
    end

    if test -f "$dest/CLAUDE.md"
        sed -i "s/PROJECT_NAME/$name/g" "$dest/CLAUDE.md"
        echo "[+] Created CLAUDE.md"
    end

    if test $demo -eq 1
        rm -f "$dest/src/main_stub.c"
    else
        if test -f "$dest/src/main_stub.c"
            rm -f "$dest/src/main.c"
            mv "$dest/src/main_stub.c" "$dest/src/main.c"
        end
    end

    sed -i "s/^PROJECT_NAME := my_project/PROJECT_NAME := $name/" "$dest/Makefile"

    pushd "$dest"
    git init -q -b main
    git add -A
    git commit -q -m "chore: init"
    popd

    echo "[+] Done: $dest"
    cd "$dest"
end

alias cproj new-cproject
alias cj new-cproject
