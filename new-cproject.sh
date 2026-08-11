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

# Writes a complete .clangd from scratch for the project dir in $1, with the
# hm_core include path given in $2. There is no committed template to patch
# — hm_mt/hm_mt_tui both .gitignore .clangd on purpose, since a --use-env
# project's correct core include path is an absolute, machine-specific path
# that must never be committed. Pass a relative path ("src/_hm_core") for
# copied-in projects (stays correct if the project moves) or an absolute
# path ($HMCOREMT_ROOT/src) for --use-env projects (see update-clangd for
# resyncing this after a project/machine move).
_hmcoremt_write_clangd() {
    local dest="$1" core_include="$2"
    cat > "$dest/.clangd" <<EOF
CompileFlags:
  Add:
    - -std=c11
    - -Isrc
    - -I$core_include
    - -Isrc/_vendor
    - -D_GNU_SOURCE
    - -DBUILD_CONSOLE_INTERFACE=1
    - -DBUILD_MULTI_TU=1
    - -DBUILD_DEBUG=0

Diagnostics:
  UnusedIncludes: None
  MissingIncludes: None

Index:
  Background: Build
EOF
}

# Regenerate .clangd for the hm_core_mt project in the current directory —
# port of the Windows Update-ClangD PowerShell function. Run this after
# moving a project (or, for --use-env projects, after $HMCOREMT_ROOT itself
# moved to a new path/machine) to resync .clangd's absolute paths.
update-clangd() {
    if [ ! -f Makefile ]; then
        echo "[!] No Makefile in current directory - run this from inside a generated hm_core_mt project." >&2
        return 1
    fi

    local core_line
    core_line=$(grep -m1 '^CORE :=' Makefile)
    if [ -z "$core_line" ]; then
        echo "[!] Couldn't find a 'CORE :=' line in Makefile - is this really an hm_core_mt project?" >&2
        return 1
    fi

    if [[ "$core_line" == *HMCOREMT_ROOT* ]]; then
        if [ -z "$HMCOREMT_ROOT" ]; then
            echo "[!] HMCOREMT_ROOT environment variable is not set." >&2
            return 1
        fi
        if [ ! -d "$HMCOREMT_ROOT" ]; then
            echo "[!] HMCOREMT_ROOT ($HMCOREMT_ROOT) does not exist." >&2
            return 1
        fi
        _hmcoremt_write_clangd "$PWD" "$HMCOREMT_ROOT/src"
        echo "[+] .clangd refreshed against live HMCOREMT_ROOT ($HMCOREMT_ROOT)"
    else
        if [ ! -d "src/_hm_core" ]; then
            echo "[!] src/_hm_core not found - is this really a copied-in hm_core_mt project?" >&2
            return 1
        fi
        _hmcoremt_write_clangd "$PWD" "src/_hm_core"
        echo "[+] .clangd refreshed (copied-in core, relative paths - safe across moves, nothing was actually stale)"
    fi
}

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
        # Makefile's CORE var points at $HMCOREMT_ROOT/src, so picking up
        # upstream core changes needs no re-copy, just a rebuild (make clean
        # if a shared header changed).
        sed -i "s|^CORE := src/_hm_core|CORE := \$(HMCOREMT_ROOT)/src|" "$dest/Makefile"
        _hmcoremt_write_clangd "$dest" "$HMCOREMT_ROOT/src"
        if [ -f "$dest/CLAUDE.md" ]; then
            sed -i "s|@src/_hm_core/CLAUDE.md|@$HMCOREMT_ROOT/CLAUDE.md|" "$dest/CLAUDE.md"
        fi
        echo "[+] Wired to live HMCOREMT_ROOT ($HMCOREMT_ROOT) - no core copy"
    else
        mkdir -p "$dest/src/_hm_core"
        cp -r "$HMCOREMT_ROOT/src/." "$dest/src/_hm_core/"
        [ -f "$HMCOREMT_ROOT/CLAUDE.md" ] && cp "$HMCOREMT_ROOT/CLAUDE.md" "$dest/src/_hm_core/CLAUDE.md"
        # Relative path — core is copied inside the project, so this stays
        # correct no matter where the project is later moved.
        _hmcoremt_write_clangd "$dest" "src/_hm_core"
    fi

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
