# Makefile — clang, true multi-TU build (see CLAUDE.md / src/_hm_core/CLAUDE.md).
#
# Mirrors hm_mt/Makefile's core source list — this app only borrows
# hm_core's base/os/ext/log layers; the GUI comes from raylib (vendor/),
# driving its own window/render loop, not hm_core's own
# draw/render/ui/window_manager stack (untouched, uncompiled here).
#
# Targets: make / make debug / make run / make clean

PROJECT_NAME := my_project

CORE := src/_hm_core
VENDOR := vendor
RAYLIB := $(VENDOR)/raylib

ifeq ($(wildcard $(CORE)/base),)
$(error hm_core not found at '$(CORE)' -- if this is a --use-env project, \
  export HMCOREMT_ROOT before running make (it's set in ~/.bash_aliases, \
  but only takes effect in a shell that has sourced it); otherwise check \
  that src/_hm_core wasn't deleted)
endif

# Same curated console-layer source list as hm_mt/Makefile (base + Linux
# os/*_linux.c + ext + log + tui + http stub + linux/base). No GUI layers.
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
INCLUDES := -Isrc -I$(CORE) -I$(RAYLIB)/include
DEFINES := -D_GNU_SOURCE -DBUILD_CONSOLE_INTERFACE=1 -DBUILD_MULTI_TU=1 \
           -DAPP_NAME=\"$(PROJECT_NAME)\"

ifeq ($(BUILD_TYPE),debug)
  DEFINES += -DBUILD_DEBUG=1
  OPT := -g -O0
else
  DEFINES += -DBUILD_DEBUG=0
  OPT := -O2
endif

# See hm_mt/Makefile for why each of these is suppressed (MSVC-parity /
# hm_core idiom noise) — same rationale applies here since this build
# shares the same CORE_SRCS.
CFLAGS := -std=c11 $(OPT) -Wall -Wno-missing-braces -Wno-initializer-overrides -Wno-unused-variable -Wno-unused-but-set-variable -Wno-unused-parameter -Wno-unused-value $(DEFINES) $(INCLUDES) -MMD -MP

# raylib static lib, then GL + X11 client libs its bundled rglfw backend
# references (raylib was built X11-only — see vendor/build_vendor.sh).
LDFLAGS := -L$(RAYLIB)/lib -lraylib \
           -lGL -lX11 -lXrandr -lXi -lXcursor -lXinerama -lXxf86vm \
           -lpthread -ldl -lm -lrt

# Object tree mirrors the source tree under $(OBJDIR) (avoids basename
# collisions across layer directories).
OBJS := $(patsubst %.c,$(OBJDIR)/%.o,$(SRCS))
DEPS := $(OBJS:.o=.d)

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
