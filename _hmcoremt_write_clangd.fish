# _hmcoremt_write_clangd.fish — internal helper shared by new-cproject and
# update-clangd. Writes a complete .clangd from scratch (there is no
# committed template to patch — hm_mt/hm_mt_tui both .gitignore .clangd on
# purpose, since a --use-env project's correct core include path is an
# absolute, machine-specific path that must never be committed).
#
# $argv[1] = project dir to write $argv[1]/.clangd into
# $argv[2] = include path for hm_core, exactly as it should appear in
#            CompileFlags.Add — pass a relative path ("src/_hm_core") for
#            copied-in projects (stays correct if the project moves, since
#            it travels with it) or an absolute path ($HMCOREMT_ROOT/src)
#            for --use-env projects (inherently external to the project, so
#            it can only be pinned as absolute — see update-clangd for
#            resyncing this after a project/machine move).
# $argv[3..] = optional extra -I dirs (e.g. hm_mt_cimgui's vendor/cimgui/include,
#              vendor/glfw/include — always relative, since vendor/ is copied
#              into the project regardless of --use-env; only hm_core itself
#              is ever referenced live).

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
        '    - -Isrc' \
        "    - -I$core_include" \
        '    - -Isrc/_vendor' \
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
