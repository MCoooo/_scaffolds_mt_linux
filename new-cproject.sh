# new-cproject.sh — Linux bash/zsh port of the Windows New-CProject PowerShell
# function. Source this file, don't execute it (it defines shell functions that
# must run in your interactive shell so the trailing `cd` works).
#
# Install: run setup.sh, or add to ~/.bash_aliases / ~/.zshrc:
#   . "/path/to/_scaffolds_mt_linux/new-cproject.sh"

# PROJECTS and HMCOREMT_ROOT: use whatever is already in the environment
# (e.g. set by setup.sh), falling back to the conventional paths.
export PROJECTS="${PROJECTS:-$HOME/dev/c_lang}"
export HMCOREMT_ROOT="${HMCOREMT_ROOT:-$HOME/dev/c_lang/_hm_core_mt}"

# ---------------------------------------------------------------------------
# _hmcoremt_write_clangd <dest> <core_include> [extra_include...]
#
# Writes .clangd from scratch. core_include for copied-in projects should
# be "_hm_core" (relative to src/), for --use-env an absolute path.
#
# WHY paths are relative to src/:
#   clangd uses the source file's own directory as working dir for its
#   fallback command (no compile_commands.json). -Isrc/_hm_core from src/
#   expands to src/src/_hm_core — wrong. -I_hm_core from src/ is correct.
# ---------------------------------------------------------------------------
_hmcoremt_write_clangd() {
    local dest="$1" core_include="$2"
    shift 2
    local extra_lines=""
    for inc in "$@"; do
        extra_lines="${extra_lines}    - -I${inc}
"
    done
    cat > "$dest/.clangd" <<EOF
CompileFlags:
  Add:
    - -std=c11
    - -I.
    - -I$core_include
    - -I_vendor
${extra_lines}    - -D_GNU_SOURCE
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

# ---------------------------------------------------------------------------
# update-clangd
#
# WHAT:  Regenerates .clangd in the current hm_core_mt project. .clangd is
#        gitignored because --use-env projects bake in an absolute path to
#        $HMCOREMT_ROOT that is machine-specific.
#
# WHEN:  - After cloning a --use-env project on a new machine: the baked-in
#          path to $HMCOREMT_ROOT only exists on the machine it was created on.
#        - If $HMCOREMT_ROOT itself moved to a different path.
#        - Copied-in projects use relative paths that never go stale — only
#          run if clangd is showing unexplained unresolved-include errors.
#        (new-cproject already runs this automatically at creation time.)
#
# USAGE: cd my-project && update-clangd
#        update-clangd --help
# ---------------------------------------------------------------------------
update-clangd() {
    if [ "${1:-}" = "--help" ]; then
        cat <<'EOF'
update-clangd — regenerate .clangd for an hm_core_mt project

WHAT:
  Rewrites .clangd in the current project directory. .clangd tells
  clangd which include paths and defines to use, and is gitignored
  (never committed) because --use-env projects bake in an absolute
  path to $HMCOREMT_ROOT that is machine-specific.

WHEN:
  - After cloning a --use-env project on a new machine: the baked-in
    path to $HMCOREMT_ROOT only exists on the machine it was created on.
  - If $HMCOREMT_ROOT itself moved to a different path.
  - Copied-in projects use relative paths that never go stale — only
    run if clangd is showing unexplained unresolved-include errors.
  (new-cproject already runs this automatically at creation time.)

USAGE:
  cd my-project && update-clangd
EOF
        return 0
    fi

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

    local extra_includes=()
    if [ -d "vendor/cimgui" ]; then
        extra_includes=(vendor/cimgui/include vendor/glfw/include)
    elif [ -d "vendor/raylib" ]; then
        extra_includes=(vendor/raylib/include)
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
        _hmcoremt_write_clangd "$PWD" "$HMCOREMT_ROOT/src" "${extra_includes[@]}"
        echo "[+] .clangd refreshed against live HMCOREMT_ROOT ($HMCOREMT_ROOT)"
    else
        if [ ! -d "src/_hm_core" ]; then
            echo "[!] src/_hm_core not found - is this really a copied-in hm_core_mt project?" >&2
            return 1
        fi
        _hmcoremt_write_clangd "$PWD" "_hm_core" "${extra_includes[@]}"
        echo "[+] .clangd refreshed (copied-in core, relative paths - safe across moves)"
    fi
}

# ---------------------------------------------------------------------------
# new-cproject <type> <name> [--use-env] [--demo]
#
# WHAT:  Creates a new hm_core_mt C project from a scaffold template.
#        Copies the scaffold, links or copies hm_core, generates .clangd
#        so clangd works out of the box, runs git init, and cd's in.
#
# WHEN:  Whenever you start a new C project using the hm_core_mt library.
#
# USAGE: new-cproject <type> <name> [--use-env] [--demo]
#        new-cproject --types
#        new-cproject --help
# ---------------------------------------------------------------------------
new-cproject() {
    local valid_types=(hm_mt hm_mt_tui hm_mt_cimgui hm_mt_raylib)
    local not_yet_ported=(hm_mt_gui std std_cimgui)

    if [ "${1:-}" = "--help" ]; then
        cat <<'EOF'
new-cproject — create a new hm_core_mt C project from a scaffold

WHAT:
  Copies a scaffold template, links or copies hm_core into it,
  generates .clangd so clangd works out of the box, runs git init,
  and cd's into the new project directory.

WHEN:
  Whenever you start a new C project using the hm_core_mt library.

USAGE:
  new-cproject <type> <name> [--use-env] [--demo]
  new-cproject --types    list available scaffold types
  new-cproject --help

TYPES:
  hm_mt          console (arenas, strings, threads, files, logging)
  hm_mt_tui      terminal UI (adds tui_core on top of hm_mt)
  hm_mt_cimgui   GUI via cimgui + GLFW + OpenGL3
  hm_mt_raylib   GUI via raylib

OPTIONS:
  --demo      Keep the full demo main.c (showcases arenas, strings,
              threads, etc.). Default is a minimal stub.
  --use-env   Reference $HMCOREMT_ROOT live instead of copying hm_core
              into src/_hm_core. Picks up upstream core changes on next
              rebuild. .clangd uses an absolute path — run update-clangd
              after cloning on a new machine or if $HMCOREMT_ROOT moves.
              Without --use-env, hm_core is a frozen snapshot inside the
              project; .clangd paths are relative and never go stale.

ALIASES: cproj, cj
EOF
        return 0
    fi

    for arg in "$@"; do
        if [ "$arg" = "--types" ]; then
            printf '%s\n' "${valid_types[@]}"
            return 0
        fi
    done

    if [ $# -lt 2 ]; then
        echo "Usage: new-cproject <type> <name> [--use-env] [--demo]" >&2
        echo "       new-cproject --help" >&2
        echo "       new-cproject --types" >&2
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
        echo "[!] PROJECTS environment variable is not set." >&2; return 1
    fi
    if [ -z "$HMCOREMT_ROOT" ]; then
        echo "[!] HMCOREMT_ROOT environment variable is not set." >&2; return 1
    fi
    if [ ! -d "$HMCOREMT_ROOT" ]; then
        echo "[!] HMCOREMT_ROOT ($HMCOREMT_ROOT) does not exist." >&2; return 1
    fi

    local scaffolds="$PROJECTS/_scaffolds_mt_linux"
    local dest="$PWD/$name"

    if [ -e "$dest" ]; then
        echo "[!] '$dest' already exists." >&2; return 1
    fi
    if [ ! -d "$scaffolds/$type" ]; then
        echo "[!] Scaffold not found: $scaffolds/$type" >&2; return 1
    fi

    echo "Creating '$name' ($type)..."
    cp -r "$scaffolds/$type" "$dest"

    local extra_includes=()
    if [ -d "$dest/vendor/cimgui" ]; then
        extra_includes=(vendor/cimgui/include vendor/glfw/include)
    elif [ -d "$dest/vendor/raylib" ]; then
        extra_includes=(vendor/raylib/include)
    fi

    if [ "$use_env" -eq 1 ]; then
        sed -i "s|^CORE := src/_hm_core|CORE := \$(HMCOREMT_ROOT)/src|" "$dest/Makefile"
        _hmcoremt_write_clangd "$dest" "$HMCOREMT_ROOT/src" "${extra_includes[@]}"
        if [ -f "$dest/CLAUDE.md" ]; then
            sed -i "s|@src/_hm_core/CLAUDE.md|@$HMCOREMT_ROOT/CLAUDE.md|" "$dest/CLAUDE.md"
        fi
        echo "[+] Wired to live HMCOREMT_ROOT ($HMCOREMT_ROOT) - no core copy"
    else
        mkdir -p "$dest/src/_hm_core"
        cp -r "$HMCOREMT_ROOT/src/." "$dest/src/_hm_core/"
        [ -f "$HMCOREMT_ROOT/CLAUDE.md" ] && cp "$HMCOREMT_ROOT/CLAUDE.md" "$dest/src/_hm_core/CLAUDE.md"
        # Paths relative to src/ — clangd's fallback runs from the source
        # file's directory, not the project root, so _hm_core resolves to
        # src/_hm_core correctly from that working directory.
        _hmcoremt_write_clangd "$dest" "_hm_core" "${extra_includes[@]}"
    fi

    if [ -f "$dest/CLAUDE.md" ]; then
        sed -i "s/PROJECT_NAME/$name/g" "$dest/CLAUDE.md"
        echo "[+] Created CLAUDE.md"
    fi

    if [ "$demo" -eq 1 ]; then
        rm -f "$dest/src/main_stub.c"
    else
        if [ -f "$dest/src/main_stub.c" ]; then
            rm -f "$dest/src/main.c"
            mv "$dest/src/main_stub.c" "$dest/src/main.c"
        fi
    fi

    sed -i "s/^PROJECT_NAME := my_project/PROJECT_NAME := $name/" "$dest/Makefile"

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
