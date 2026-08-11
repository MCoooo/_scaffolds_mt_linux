#include "config.h"

#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>

void config_get_dir(char *out, int size) {
    const char *home = getenv("HOME");
    if (!home) { out[0] = '\0'; return; }
    snprintf(out, size, "%s/.config/" CONFIG_FOLDER "/", home);
}

void config_ensure_dir(void) {
    const char *home = getenv("HOME");
    if (!home) return;
    char tmp[CONFIG_MAX_PATH];
    snprintf(tmp, sizeof(tmp), "%s/.config", home);
    mkdir(tmp, 0755);
    snprintf(tmp, sizeof(tmp), "%s/.config/" CONFIG_FOLDER, home);
    mkdir(tmp, 0755);
}

void config_get_ini_path(char *out, int size) {
    char dir[CONFIG_MAX_PATH];
    config_get_dir(dir, sizeof(dir));
    snprintf(out, size, "%simgui.ini", dir);
}
