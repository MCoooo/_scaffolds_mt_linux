# Setup

Fresh-machine instructions for `new-cproject` on WSL2/native Linux. Assumes
Ubuntu/Debian (`apt`); adjust package manager for other distros.

## 1. Prerequisites

```sh
sudo apt-get update
sudo apt-get install -y clang clangd git
```

Optional but recommended — clipboard support (`os_clipboard_linux.c` shells
out to one of these depending on `$WAYLAND_DISPLAY`/`$DISPLAY`; without
either installed, clipboard calls fail silently and return empty):

```sh
sudo apt-get install -y wl-clipboard   # WSLg / Wayland sessions (check: echo $WAYLAND_DISPLAY)
sudo apt-get install -y xclip          # plain X11 sessions
```

Git identity, if you haven't set one on this machine yet (needed for the
`git commit` step `new-cproject` runs at the end of scaffolding — it warns
but doesn't fail if this is missing):

```sh
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

## 2. Clone the two repos

```sh
mkdir -p ~/dev/c_lang
git clone https://github.com/MCoooo/hm_core_mt.git        ~/dev/c_lang/_hm_core_mt
git clone https://github.com/MCoooo/_scaffolds_mt_linux.git ~/dev/c_lang/_scaffolds_mt_linux
```

(If you're setting this up alongside an existing Windows checkout on the
same machine, clone natively into the Linux filesystem as above rather than
working out of `/mnt/c`/`/mnt/d` — DrvFs is noticeably slower for
many-small-file workloads like a multi-TU C build and `clangd` indexing.
`~/dev/c_lang` isn't load-bearing as a path — `new-cproject.sh` only cares
that `PROJECTS`/`HMCOREMT_ROOT` point at wherever you actually put things,
see step 3.)

## 3. Wire up `new-cproject`

```sh
mkdir -p ~/.bash_aliases  # no-op if it's already a file; see note below
cat >> ~/.bashrc <<'EOF'
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi
EOF
```

Stock Ubuntu `.bashrc` already has that `if [ -f ~/.bash_aliases ]` block —
check first (`grep bash_aliases ~/.bashrc`) before appending a duplicate.

Then create `~/.bash_aliases` (or add to it, if you already use one for
other things):

```sh
cat >> ~/.bash_aliases <<'EOF'
if [ -f "$HOME/dev/c_lang/_scaffolds_mt_linux/new-cproject.sh" ]; then
    . "$HOME/dev/c_lang/_scaffolds_mt_linux/new-cproject.sh"
fi
EOF
```

If you cloned to somewhere other than `~/dev/c_lang`, either adjust that
path, or just edit the `PROJECTS`/`HMCOREMT_ROOT` exports at the top of
`new-cproject.sh` directly.

Open a new terminal (or `source ~/.bashrc`) to pick it up.

## 4. Verify

```sh
mkdir -p ~/dev/c_lang/tmp && cd ~/dev/c_lang/tmp
new-cproject hm_mt hello --demo
make run
cd .. && rm -rf tmp/hello
```

Should print a demo run (arenas, strings, json/toml/ini, threads, files,
logging) and end with `done.`.

## Usage

```sh
new-cproject <hm_mt|hm_mt_tui> <name> [--use-env] [--demo]
# aliases: cproj, cj
```

- `--demo` — keep the full demo `main.c` (arenas/strings/threads/tui showcase
  etc.); default is a minimal `main_stub.c` renamed to `main.c`.
- `--use-env` — reference `$HMCOREMT_ROOT/src` live instead of copying it
  into `src/_hm_core/`; upstream core changes are picked up on next rebuild
  (no re-run needed). Without it, the project gets a frozen snapshot.

Inside a generated project: `make` / `make debug` / `make run` / `make clean`.

## Known gaps

- Only `hm_mt` (console) and `hm_mt_tui` (terminal UI) exist. GUI scaffolds
  aren't ported — see this repo's `CLAUDE.md` "Not ported yet" section.
- `make debug`/`make` both work but there's no `compile_commands.json`
  generation step yet (the checked-in `.clangd`, regenerated with absolute
  paths at project-creation time, is what `clangd` actually uses — this is
  sufficient, just noting `compile_commands.json` specifically isn't
  produced if some other tool expects it).
