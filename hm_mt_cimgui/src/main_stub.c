// ============================================================
// main.c — minimal hm_core + cimgui starting point (mt / true multi-TU build).
//
// ENTRY-POINT CONTRACT: this app does not define main().
// See _hm_core/NOTES.md for the full call chain.
//
// cimgui/GLFW drive their own window + render loop directly — they are
// NOT part of hm_core's own GUI stack (draw/render/ui/window_manager),
// which stays uncompiled here. Only base/os/ext/log are borrowed.
// ============================================================

#include "inc.h"

#ifndef CIMGUI_DEFINE_ENUMS_AND_STRUCTS
#define CIMGUI_DEFINE_ENUMS_AND_STRUCTS
#endif
#include "cimgui.h"
#include "config.h"

#include <GL/gl.h>
#include <GLFW/glfw3.h>
#include "cimgui_impl.h"

internal void
glfw_error_callback(int error, const char *description)
{
    lg_error("GLFW error %d: %s", error, description);
}

internal void
glfw_resize_callback(GLFWwindow *window, int w, int h)
{
    (void)window;
    glViewport(0, 0, w, h);
}

internal void
entry_point(CmdLine *cmdline)
{
    (void)cmdline;
    lg_init(LG_Level_Info);
    lg_add_stdout_sink();

    glfwSetErrorCallback(glfw_error_callback);
    if (!glfwInit()) { lg_error("glfwInit failed"); return; }
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    GLFWwindow *window = glfwCreateWindow(1280, 720, APP_NAME, NULL, NULL);
    if (!window) { glfwTerminate(); lg_error("glfwCreateWindow failed"); return; }
    glfwSetFramebufferSizeCallback(window, glfw_resize_callback);
    glfwMakeContextCurrent(window);
    glfwSwapInterval(1);

    igCreateContext(NULL);
    ImGuiIO *io = igGetIO_Nil();
    static char imgui_ini_path[CONFIG_MAX_PATH];
    config_ensure_dir();
    config_get_ini_path(imgui_ini_path, sizeof(imgui_ini_path));
    io->IniFilename = imgui_ini_path;
    io->ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
    ImGui_ImplGlfw_InitForOpenGL(window, true);
    ImGui_ImplOpenGL3_Init("#version 330 core");

    while (!glfwWindowShouldClose(window))
    {
        glfwPollEvents();

        ImGui_ImplOpenGL3_NewFrame();
        ImGui_ImplGlfw_NewFrame();
        igNewFrame();

        // ...

        igRender();
        int w, h;
        glfwGetFramebufferSize(window, &w, &h);
        glViewport(0, 0, w, h);
        glClearColor(0.1f, 0.1f, 0.1f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        ImGui_ImplOpenGL3_RenderDrawData(igGetDrawData());
        glfwSwapBuffers(window);
    }

    ImGui_ImplOpenGL3_Shutdown();
    ImGui_ImplGlfw_Shutdown();
    igDestroyContext(NULL);
    glfwDestroyWindow(window);
    glfwTerminate();
    lg_shutdown();
}
