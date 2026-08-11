# update-clangd.fish — fish port of the Windows Update-ClangD PowerShell
# function. Run from inside an already-generated hm_core_mt project to
# resync its .clangd after the project (or, for --use-env projects,
# $HMCOREMT_ROOT) has moved to a new path or machine. See CLAUDE.md for why
# .clangd can't just be committed once and forgotten.

function update-clangd --description "Regenerate .clangd for the hm_core_mt project in the current directory"
    if not test -f Makefile
        echo "[!] No Makefile in current directory - run this from inside a generated hm_core_mt project." >&2
        return 1
    end

    set core_line (grep -m1 '^CORE :=' Makefile)
    if test -z "$core_line"
        echo "[!] Couldn't find a 'CORE :=' line in Makefile - is this really an hm_core_mt project?" >&2
        return 1
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
        _hmcoremt_write_clangd "$PWD" "$HMCOREMT_ROOT/src"
        echo "[+] .clangd refreshed against live HMCOREMT_ROOT ($HMCOREMT_ROOT)"
    else
        if not test -d "src/_hm_core"
            echo "[!] src/_hm_core not found - is this really a copied-in hm_core_mt project?" >&2
            return 1
        end
        _hmcoremt_write_clangd "$PWD" "src/_hm_core"
        echo "[+] .clangd refreshed (copied-in core, relative paths - safe across moves, nothing was actually stale)"
    end
end
