# update-clangd.fish — fish port of the Windows Update-ClangD PowerShell
# function. Install: cp update-clangd.fish _hmcoremt_write_clangd.fish ~/.config/fish/functions/
# Or run setup.sh to install everything at once.

function update-clangd --description "Regenerate .clangd for the hm_core_mt project in the current directory"
    if contains -- --help $argv
        echo "update-clangd — regenerate .clangd for an hm_core_mt project"
        echo ""
        echo "WHAT:"
        echo "  Rewrites .clangd in the current project directory. .clangd tells"
        echo "  clangd which include paths and defines to use, and is gitignored"
        echo "  (never committed) because --use-env projects bake in an absolute"
        echo "  path to \$HMCOREMT_ROOT that is machine-specific."
        echo ""
        echo "WHEN:"
        echo "  - After cloning a --use-env project on a new machine: the baked-in"
        echo "    path to \$HMCOREMT_ROOT only exists on the machine it was created on."
        echo "  - If \$HMCOREMT_ROOT itself moved to a different path."
        echo "  - Copied-in projects use relative paths that never go stale — only"
        echo "    run if clangd is showing unexplained unresolved-include errors."
        echo "  (new-cproject already runs this automatically at creation time.)"
        echo ""
        echo "USAGE:"
        echo "  cd my-project && update-clangd"
        return 0
    end

    if not test -f Makefile
        echo "[!] No Makefile in current directory - run this from inside a generated hm_core_mt project." >&2
        return 1
    end

    set core_line (grep -m1 '^CORE :=' Makefile)
    if test -z "$core_line"
        echo "[!] Couldn't find a 'CORE :=' line in Makefile - is this really an hm_core_mt project?" >&2
        return 1
    end

    # vendor/ (cimgui+GLFW, or raylib, when present) is always local to the
    # project, copy-in or --use-env alike — same reasoning as new-cproject.
    set extra_includes
    if test -d vendor/cimgui
        set extra_includes vendor/cimgui/include vendor/glfw/include
    else if test -d vendor/raylib
        set extra_includes vendor/raylib/include
    end

    if string match -q '*HMCOREMT_ROOT*' -- $core_line
        if test -z "$HMCOREMT_ROOT"
            echo "[!] HMCOREMT_ROOT environment variable is not set." >&2
            return 1
        end
        if not test -d "$HMCOREMT_ROOT"
            echo "[!] HMCOREMT_ROOT ($HMCOREMT_ROOT) does not exist." >&2
            return 1
        end
        _hmcoremt_write_clangd "$PWD" "$HMCOREMT_ROOT/src" $extra_includes
        echo "[+] .clangd refreshed against live HMCOREMT_ROOT ($HMCOREMT_ROOT)"
    else
        if not test -d "src/_hm_core"
            echo "[!] src/_hm_core not found - is this really a copied-in hm_core_mt project?" >&2
            return 1
        end
        _hmcoremt_write_clangd "$PWD" "_hm_core" $extra_includes
        echo "[+] .clangd refreshed (copied-in core, relative paths - safe across moves)"
    end
end
