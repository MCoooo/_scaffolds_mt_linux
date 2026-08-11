# Makefile — clang, true multi-TU build (see CLAUDE.md / src/_hm_core/CLAUDE.md).
#
# Mirrors the Windows scaffold's build.bat source list. Unlike build.bat,
# there's no separate incremental-build script here: clang's -MMD/-MP
# generate a .d dependency sidecar per object automatically, and make's own
# timestamp/prereq tracking does the rest — a header edit under src/_hm_core
# correctly triggers exactly the TUs that include it, no wrapper needed.
#
# Targets: make / make debug / make run / make clean

PROJECT_NAME := my_project

CORE := src/_hm_core

ifeq ($(wildcard $(CORE)/base),)
$(error hm_core not found at '$(CORE)' -- if this is a --use-env project, \
  export HMCOREMT_ROOT before running make (it's set in ~/.bash_aliases, \
  but only takes effect in a shell that has sourced it); otherwise check \
  that src/_hm_core wasn't deleted)
endif

# Curated source list (not a recursive glob) — same layer set as build.bat's
# SOURCES_FILE glob, swapped to the *_linux.c siblings for os/. os_registry.c
# is Windows-only (no Linux registry) and dropped; main.c already guards its
# one registry call behind #if OS_WINDOWS. ext_keybind.c needs window_manager
# (X11), so it's excluded here same as the Windows console (non-GUI) build.
CORE_SRCS := \
  $(wildcard $(CORE)/base/*.c) \
  $(CORE)/os/os_clipboard_linux.c \
  $(CORE)/os/os_console_linux.c \
  $(CORE)/os/os_env_linux.c \
  $(filter-out $(CORE)/ext/ext_keybind.c,$(wildcard $(CORE)/ext/*.c)) \
  $(CORE)/log/lg.c \
  $(CORE)/tui/tui_core.c \
  $(CORE)/http/http.c \
  $(CORE)/linux/base/linux_base.c

PROJECT_SRCS := $(wildcard src/*.c)
SRCS := $(CORE_SRCS) $(PROJECT_SRCS)

BUILD_TYPE ?= release
OBJDIR := obj/$(BUILD_TYPE)
BINDIR := bin
BIN := $(BINDIR)/$(PROJECT_NAME)

CC := clang
INCLUDES := -Isrc -I$(CORE) -Isrc/_vendor
DEFINES := -D_GNU_SOURCE -DBUILD_CONSOLE_INTERFACE=1 -DBUILD_MULTI_TU=1

ifeq ($(BUILD_TYPE),debug)
  DEFINES += -DBUILD_DEBUG=1
  OPT := -g -O0
else
  DEFINES += -DBUILD_DEBUG=0
  OPT := -O2
endif

# -Wno-missing-braces / -Wno-initializer-overrides: hm_core's idioms (nested
# struct literals without extra braces; the arena_alloc(...)-style "defaults
# struct + override specific fields" designated-initializer macro pattern)
# trip these Clang-only pedantic warnings hundreds of times per build.
# GCC/MSVC don't warn on either by default. Genuine warnings (unused vars,
# etc.) stay live via -Wall.
# Suppressions here are deliberately narrow and cross-checked against the
# Windows build.bat's /wd list (see _scaffolds_mt/hm_mt/build.bat), not
# guessed:
#   -Wno-missing-braces / -Wno-initializer-overrides: no MSVC /W3 equivalent
#     exists for either — hm_core's idioms (nested struct literals without
#     extra braces; the arena_alloc(...)-style "defaults struct + override
#     specific fields" designated-initializer macro) trip these Clang-only
#     pedantic checks hundreds of times per build for patterns MSVC doesn't
#     diagnose at all.
#   -Wno-unused-variable / -Wno-unused-but-set-variable / -Wno-unused-parameter:
#     direct match for Windows' /wd4101, /wd4189, /wd4100 — hm_core has
#     debug/assert-only locals and callback-signature parameters that go
#     genuinely unused throughout the vendored layers (unused-parameter
#     isn't currently tripped by this build's source set, but will be once
#     more of hm_core's surface is compiled — keeping it here for parity
#     rather than waiting to notice the noise later).
# Everything else stays live via -Wall, including in your own src/*.c.
CFLAGS := -std=c11 $(OPT) -Wall -Wno-missing-braces -Wno-initializer-overrides -Wno-unused-variable -Wno-unused-but-set-variable -Wno-unused-parameter -Wno-unused-value $(DEFINES) $(INCLUDES) -MMD -MP
LDFLAGS := -lpthread -ldl -lm

# Object tree mirrors the source tree under $(OBJDIR) (avoids basename
# collisions across layer directories).
OBJS := $(patsubst %.c,$(OBJDIR)/%.o,$(SRCS))
DEPS := $(OBJS:.o=.d)

# Quiet by default (`CC file.c` / `LD binary`); `make V=1` shows the full
# clang invocation per file instead. Either way, clang's own stdout/stderr
# (warnings, errors) always prints in full — this only silences the
# command-line echo, not diagnostics.
ifeq ($(V),1)
  Q :=
else
  Q := @
endif

.PHONY: all debug run clean
all: $(BIN)

debug:
	@$(MAKE) BUILD_TYPE=debug all

$(BIN): $(OBJS)
	@mkdir -p $(BINDIR)
	@echo "  LD      $@"
	$(Q)$(CC) $(OBJS) -o $@ $(LDFLAGS)
	@echo "[+] Build successful: $@"

$(OBJDIR)/%.o: %.c
	@mkdir -p $(dir $@)
	@echo "  CC      $<"
	$(Q)$(CC) $(CFLAGS) -c $< -o $@

run: all
	@./$(BIN)

clean:
	rm -rf bin obj

-include $(DEPS)
