#!/usr/bin/env bash
# setup.sh — first-machine / fresh-clone setup for hm_core_mt on Linux.
#
# WHAT:
#   Installs new-cproject, update-clangd, and their helpers into your shell,
#   wires up PROJECTS and HMCOREMT_ROOT, and checks prerequisites.
#
# WHEN:
#   Run once after cloning both repos on a new machine:
#     git clone ... _hm_core_mt
#     git clone ... _scaffolds_mt_linux
#     bash _scaffolds_mt_linux/setup.sh [fish|bash|zsh]
#
# USAGE:
#   bash setup.sh [fish|bash|zsh]   # shell arg is optional, autodetects from $SHELL
#   bash setup.sh --help

set -euo pipefail

SCAFFOLDS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_DIR="$(dirname "$SCAFFOLDS_DIR")"
HMCOREMT_DEFAULT="$PROJECTS_DIR/_hm_core_mt"

# ---------------------------------------------------------------------------
# --help
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    cat <<EOF
setup.sh — first-machine / fresh-clone setup for hm_core_mt on Linux

WHAT:
  Installs new-cproject and update-clangd into your shell, sets PROJECTS
  and HMCOREMT_ROOT environment variables, and checks prerequisites.

WHEN:
  Run once on a new machine after cloning both repos:
    git clone ... _hm_core_mt        (your hm_core library)
    git clone ... _scaffolds_mt_linux (this repo)
    bash _scaffolds_mt_linux/setup.sh [fish|bash|zsh]

USAGE:
  bash setup.sh [fish|bash|zsh]
  bash setup.sh --help

  Shell argument is optional — autodetected from \$SHELL if omitted.

PATHS DETECTED FROM THIS SCRIPT'S LOCATION:
  PROJECTS      = $PROJECTS_DIR
  HMCOREMT_ROOT = $HMCOREMT_DEFAULT

  If these are wrong, move the repos to the right place first, or edit
  the generated config lines manually after running setup.

AFTER SETUP:
  Open a new terminal (or source your shell config), then:
    new-cproject --help
    update-clangd --help
EOF
    exit 0
fi

# ---------------------------------------------------------------------------
# Detect shell
# ---------------------------------------------------------------------------
SHELL_TYPE="${1:-}"
if [ -z "$SHELL_TYPE" ]; then
    case "${SHELL:-}" in
        */fish) SHELL_TYPE=fish ;;
        */zsh)  SHELL_TYPE=zsh  ;;
        *)      SHELL_TYPE=bash ;;
    esac
    echo "[i] Detected shell: $SHELL_TYPE (pass fish/bash/zsh to override)"
fi

case "$SHELL_TYPE" in
    fish|bash|zsh) ;;
    *)
        echo "[!] Unknown shell '$SHELL_TYPE'. Use: fish, bash, or zsh" >&2
        exit 1
        ;;
esac

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------
echo ""
echo "[i] Checking prerequisites..."
ALL_OK=1
for cmd in clang clangd git; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "    [+] $cmd ($(command -v "$cmd"))"
    else
        echo "    [!] $cmd not found"
        ALL_OK=0
    fi
done
if [ "$ALL_OK" -eq 0 ]; then
    echo ""
    echo "    Install missing tools: sudo apt-get install clang clangd git"
fi

# ---------------------------------------------------------------------------
# Show paths
# ---------------------------------------------------------------------------
echo ""
echo "[i] Paths:"
echo "    PROJECTS      = $PROJECTS_DIR"
echo "    HMCOREMT_ROOT = $HMCOREMT_DEFAULT"
if [ ! -d "$HMCOREMT_DEFAULT" ]; then
    echo ""
    echo "    [!] _hm_core_mt not found at $HMCOREMT_DEFAULT"
    echo "        Clone it there, or the env vars will need fixing manually."
fi
echo ""

# ---------------------------------------------------------------------------
# Install: fish
# ---------------------------------------------------------------------------
if [ "$SHELL_TYPE" = "fish" ]; then
    FISH_FUNCS="$HOME/.config/fish/functions"
    mkdir -p "$FISH_FUNCS"

    echo "[i] Copying fish functions to $FISH_FUNCS ..."
    FISH_FILES=(new-cproject.fish update-clangd.fish _hmcoremt_write_clangd.fish cproj.fish cj.fish)
    for f in "${FISH_FILES[@]}"; do
        if [ -f "$SCAFFOLDS_DIR/$f" ]; then
            cp "$SCAFFOLDS_DIR/$f" "$FISH_FUNCS/$f"
            echo "    [+] $f"
        fi
    done

    FISH_CONFIG="$HOME/.config/fish/config.fish"
    mkdir -p "$(dirname "$FISH_CONFIG")"
    touch "$FISH_CONFIG"

    if grep -q "HMCOREMT_ROOT" "$FISH_CONFIG" 2>/dev/null; then
        echo "[i] HMCOREMT_ROOT already in $FISH_CONFIG — skipping"
        echo "    Edit manually if the paths have changed."
    else
        cat >> "$FISH_CONFIG" <<EOF

# hm_core_mt — added by setup.sh
set -x PROJECTS $PROJECTS_DIR
set -x HMCOREMT_ROOT $HMCOREMT_DEFAULT
EOF
        echo "[+] Added PROJECTS and HMCOREMT_ROOT to $FISH_CONFIG"
    fi

# ---------------------------------------------------------------------------
# Install: bash or zsh
# ---------------------------------------------------------------------------
else
    if [ "$SHELL_TYPE" = "bash" ]; then
        RC="$HOME/.bashrc"
        ALIASES="$HOME/.bash_aliases"
        # Ensure .bashrc sources .bash_aliases (standard on Ubuntu, but not everywhere)
        if ! grep -q "bash_aliases" "$RC" 2>/dev/null; then
            cat >> "$RC" <<'EOF'

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi
EOF
            echo "[+] Added bash_aliases sourcing block to $RC"
        fi
        TARGET="$ALIASES"
    else
        # zsh: source directly in .zshrc
        RC="$HOME/.zshrc"
        TARGET="$RC"
        touch "$RC"
    fi

    SOURCE_LINE=". \"$SCAFFOLDS_DIR/new-cproject.sh\""
    ENV_LINES="export PROJECTS=\"$PROJECTS_DIR\"
export HMCOREMT_ROOT=\"$HMCOREMT_DEFAULT\""

    if grep -q "HMCOREMT_ROOT" "$TARGET" 2>/dev/null; then
        echo "[i] HMCOREMT_ROOT already in $TARGET — skipping env vars"
        echo "    Edit manually if the paths have changed."
    else
        {
            echo ""
            echo "# hm_core_mt — added by setup.sh"
            echo "$ENV_LINES"
        } >> "$TARGET"
        echo "[+] Added PROJECTS and HMCOREMT_ROOT to $TARGET"
    fi

    if grep -q "new-cproject.sh" "$TARGET" 2>/dev/null; then
        echo "[i] new-cproject.sh already sourced in $TARGET — skipping"
    else
        echo "$SOURCE_LINE" >> "$TARGET"
        echo "[+] Added source line to $TARGET"
    fi
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo "[+] Setup complete."
echo ""
echo "    Open a new terminal (or source your config), then:"
echo "      new-cproject --help"
echo "      update-clangd --help"
