# new-cproject.sh — Linux port of the Windows New-CProject PowerShell
# function. See SETUP.md for installation. Source this file, don't execute
# it (it defines a shell function + exports + aliases in your interactive
# shell, nothing here does anything on its own).
#
# It's a *function*, not a standalone script on PATH, because PowerShell's
# New-CProject ends with Set-Location $dest, leaving you inside the new
# project — a script run in a subprocess can't cd its parent shell, so this
# has to run in-process via `source`.

export PROJECTS="$HOME/dev/c_lang"
export HMCOREMT_ROOT="$HOME/dev/c_lang/_hm_core_mt"

# Creates a new cproject based on scaffold types (type, name, [--use-env], [--demo])
new-cproject() {
    local valid_types=(hm_mt hm_mt_tui)
    local not_yet_ported=(hm_mt_gui hm_mt_cimgui hm_mt_raylib std std_cimgui)

    if [ $# -lt 2 ]; then
        echo "Usage: new-cproject <type> <name> [--use-env] [--demo]" >&2
        echo "Types: ${valid_types[*]}" >&2
        echo "(GUI/raylib/cimgui/std types not yet ported to Linux)" >&2
        return 1
    fi

    local type="$1" name="$2"
    shift 2
    local use_env=0 demo=0
    for arg in "$@"; do
        case "$arg" in
            --use-env) use_env=1 ;;
            --demo)    demo=1 ;;
            *)
                echo "[!] Unknown option '$arg'." >&2
                return 1
                ;;
        esac
    done

    local is_valid=0
    for t in "${valid_types[@]}"; do [ "$t" = "$type" ] && is_valid=1; done
    if [ "$is_valid" -eq 0 ]; then
        for t in "${not_yet_ported[@]}"; do
            if [ "$t" = "$type" ]; then
                echo "[!] '$type' is not yet ported to Linux (see _hm_core_mt Phase 2 notes)." >&2
                return 1
            fi
        done
        echo "[!] Unknown project type '$type'. Valid: ${valid_types[*]}" >&2
        return 1
    fi

    if [ -z "$PROJECTS" ]; then
        echo "[!] PROJECTS environment variable is not set." >&2
        return 1
    fi
    if [ -z "$HMCOREMT_ROOT" ]; then
        echo "[!] HMCOREMT_ROOT environment variable is not set." >&2
        return 1
    fi
    if [ ! -d "$HMCOREMT_ROOT" ]; then
        echo "[!] HMCOREMT_ROOT ($HMCOREMT_ROOT) does not exist." >&2
        return 1
    fi

    local scaffolds="$PROJECTS/_scaffolds_mt_linux"
    local dest="$PWD/$name"

    if [ -e "$dest" ]; then
        echo "[!] '$dest' already exists." >&2
        return 1
    fi
    if [ ! -d "$scaffolds/$type" ]; then
        echo "[!] Scaffold not found: $scaffolds/$type" >&2
        return 1
    fi

    echo "Creating '$name' ($type)..."
    cp -r "$scaffolds/$type" "$dest"

    if [ "$use_env" -eq 1 ]; then
        # Reference hm_core live via $HMCOREMT_ROOT instead of copying it in —
        # Makefile's CORE var and .clangd point at $HMCOREMT_ROOT/src, so
        # picking up upstream core changes needs no re-copy, just a rebuild
        # (make clean if a shared header changed).
        sed -i "s|^CORE := src/_hm_core|CORE := \$(HMCOREMT_ROOT)/src|" "$dest/Makefile"
        sed -i "s|- -Isrc/_hm_core|- -I$HMCOREMT_ROOT/src|" "$dest/.clangd"
        if [ -f "$dest/CLAUDE.md" ]; then
            sed -i "s|@src/_hm_core/CLAUDE.md|@$HMCOREMT_ROOT/CLAUDE.md|" "$dest/CLAUDE.md"
        fi
        echo "[+] Wired to live HMCOREMT_ROOT ($HMCOREMT_ROOT) - no core copy"
    else
        mkdir -p "$dest/src/_hm_core"
        cp -r "$HMCOREMT_ROOT/src/." "$dest/src/_hm_core/"
        [ -f "$HMCOREMT_ROOT/CLAUDE.md" ] && cp "$HMCOREMT_ROOT/CLAUDE.md" "$dest/src/_hm_core/CLAUDE.md"
        sed -i "s|- -Isrc/_hm_core|- -I$dest/src/_hm_core|" "$dest/.clangd"
    fi
    sed -i "s|- -Isrc/_vendor|- -I$dest/src/_vendor|" "$dest/.clangd"
    sed -i "s|- -Isrc\$|- -I$dest/src|" "$dest/.clangd"

    # Project root CLAUDE.md: patch PROJECT_NAME in place
    if [ -f "$dest/CLAUDE.md" ]; then
        sed -i "s/PROJECT_NAME/$name/g" "$dest/CLAUDE.md"
        echo "[+] Created CLAUDE.md"
    fi

    # Demo vs minimal entry point
    if [ "$demo" -eq 1 ]; then
        rm -f "$dest/src/main_stub.c"
    else
        if [ -f "$dest/src/main_stub.c" ]; then
            rm -f "$dest/src/main.c"
            mv "$dest/src/main_stub.c" "$dest/src/main.c"
        fi
    fi

    # Patch PROJECT_NAME in Makefile
    sed -i "s/^PROJECT_NAME := my_project/PROJECT_NAME := $name/" "$dest/Makefile"

    # Git init
    (
        cd "$dest"
        git init -q -b main
        git add -A
        git commit -q -m "chore: init"
    )

    echo "[+] Done: $dest"
    cd "$dest" || return 1
}

alias cproj='new-cproject'
alias cj='new-cproject'
