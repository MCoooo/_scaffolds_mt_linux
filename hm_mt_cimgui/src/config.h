#pragma once
#define CONFIG_MAX_PATH 260

#ifndef APP_NAME
#define APP_NAME "default_app"
#endif

#ifndef CONFIG_FOLDER
#define CONFIG_FOLDER APP_NAME
#endif

void config_get_dir(char *out, int size);
void config_ensure_dir(void);
void config_get_ini_path(char *out, int size);
