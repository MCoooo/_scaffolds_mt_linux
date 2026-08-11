# _hmcoremt_write_clangd.fish — internal helper shared by new-cproject and
# update-clangd. Writes a complete .clangd from scratch (there is no
# committed template to patch — hm_mt/hm_mt_tui both .gitignore .clangd on
# purpose, since a --use-env project's correct core include path is an
# absolute, machine-specific path that must never be committed).
#
# $argv[1] = project dir to write $argv[1]/.clangd into
# $argv[2] = include path for hm_core as it should appear in CompileFlags.Add:
#              copied-in  → "_hm_core"          (relative to src/, travels with project)
#              --use-env  → "$HMCOREMT_ROOT/src" (absolute, resync with update-clangd after move)
#
# IMPORTANT — why paths are relative to src/, not the project root:
#   clangd has no compile_commands.json, so it uses a "generic fallback"
#   command whose working directory is the SOURCE FILE's own directory
#   (src/ for project files). Paths like -Isrc/_hm_core would expand to
#   src/src/_hm_core from that working directory — wrong. Use paths that
#   resolve correctly from src/: -I. for src/ itself, -I_hm_core for
#   src/_hm_core, etc. Absolute paths (--use-env) are unaffected by this.
#
# $argv[3..] = optional extra -I dirs, already expressed relative to src/
#              (e.g. "../vendor/cimgui/include" for hm_mt_cimgui projects).

function _hmcoremt_write_clangd --description "Write a fresh .clangd for an hm_core_mt project (internal helper)"
    set dest $argv[1]
    set core_include $argv[2]
    set extra_includes $argv[3..-1]

    set extra_lines
    for inc in $extra_includes
        set extra_lines $extra_lines "    - -I$inc"
    end

    printf '%s\n' \
        'CompileFlags:' \
        '  Add:' \
        '    - -std=c11' \
        '    - -I.' \
        "    - -I$core_include" \
        '    - -I_vendor' \
        $extra_lines \
        '    - -D_GNU_SOURCE' \
        '    - -DBUILD_CONSOLE_INTERFACE=1' \
        '    - -DBUILD_MULTI_TU=1' \
        '    - -DBUILD_DEBUG=0' \
        '' \
        'Diagnostics:' \
        '  UnusedIncludes: None' \
        '  MissingIncludes: None' \
        '' \
        'Index:' \
        '  Background: Build' \
        > "$dest/.clangd"
end
