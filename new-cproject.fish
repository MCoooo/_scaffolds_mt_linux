# new-cproject.fish — fish-native port of new-cproject.sh (which itself
# ports the Windows New-CProject PowerShell function). See SETUP.md for
# installation. Autoloaded from ~/.config/fish/functions/ — no sourcing
# step needed (unlike the bash version's ~/.bash_aliases dance): fish
# functions already run in the caller's shell, so `cd $dest` at the end
# just works.

function new-cproject --description "Create a new hm_core_mt project from a Linux scaffold"
    set valid_types hm_mt hm_mt_tui hm_mt_cimgui
    set not_yet_ported hm_mt_gui hm_mt_raylib std std_cimgui

    if contains -- --types $argv
        for t in $valid_types
            echo $t
        end
        return 0
    end

    if test (count $argv) -lt 2
        echo "Usage: new-cproject <type> <name> [--use-env] [--demo]" >&2
        echo "       new-cproject --types" >&2
        echo "Types: $valid_types" >&2
        echo "(GUI/raylib/std types not yet ported to Linux)" >&2
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

    # vendor/ (cimgui+GLFW, when present) is copied in as part of the
    # template regardless of --use-env — it's the scaffold's own vendored
    # dependency, not hm_core, so the live-vs-copy choice doesn't apply to
    # it. Its include dirs still need to land in .clangd though.
    set extra_includes
    if test -d "$dest/vendor/cimgui"
        set extra_includes vendor/cimgui/include vendor/glfw/include
    end

    if test $use_env -eq 1
        # Reference hm_core live via $HMCOREMT_ROOT instead of copying it in —
        # Makefile's CORE var points at $HMCOREMT_ROOT/src, so picking up
        # upstream core changes needs no re-copy, just a rebuild (make clean
        # if a shared header changed). .clangd's core include is necessarily
        # an absolute, machine-specific path in this mode (hm_core lives
        # outside the project) — if this project is later moved to another
        # machine (or $HMCOREMT_ROOT itself moves), re-run `update-clangd`
        # inside it to resync. That's exactly why .clangd is .gitignore'd
        # rather than committed: a baked-in absolute path from machine A
        # would silently be wrong on machine B.
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
        # Relative path — core is copied inside the project, so this stays
        # correct no matter where the project is later moved. No absolute
        # path, no staleness, update-clangd is a no-op here.
        _hmcoremt_write_clangd "$dest" "src/_hm_core" $extra_includes
    end

    # Project root CLAUDE.md: patch PROJECT_NAME in place
    if test -f "$dest/CLAUDE.md"
        sed -i "s/PROJECT_NAME/$name/g" "$dest/CLAUDE.md"
        echo "[+] Created CLAUDE.md"
    end

    # Demo vs minimal entry point
    if test $demo -eq 1
        rm -f "$dest/src/main_stub.c"
    else
        if test -f "$dest/src/main_stub.c"
            rm -f "$dest/src/main.c"
            mv "$dest/src/main_stub.c" "$dest/src/main.c"
        end
    end

    # Patch PROJECT_NAME in Makefile
    sed -i "s/^PROJECT_NAME := my_project/PROJECT_NAME := $name/" "$dest/Makefile"

    # Git init
    pushd "$dest"
    git init -q -b main
    git add -A
    git commit -q -m "chore: init"
    popd

    echo "[+] Done: $dest"
    cd "$dest"
end
