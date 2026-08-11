// Minimal C declarations for the imgui GLFW + OpenGL3 backends (Linux).
//
// Include order in your .c file:
//   #include "cimgui.h"          <- defines ImDrawData
//   #include <GLFW/glfw3.h>      <- defines GLFWwindow
//   #include "cimgui_impl.h"     <- this file

#pragma once
#include <stdbool.h>

typedef struct GLFWwindow GLFWwindow;

#ifdef __cplusplus
extern "C" {
#endif

// --- GLFW ---
bool ImGui_ImplGlfw_InitForOpenGL(GLFWwindow* window, bool install_callbacks);
void ImGui_ImplGlfw_Shutdown(void);
void ImGui_ImplGlfw_NewFrame(void);

// --- OpenGL3 ---
bool ImGui_ImplOpenGL3_Init(const char* glsl_version);
void ImGui_ImplOpenGL3_Shutdown(void);
void ImGui_ImplOpenGL3_NewFrame(void);
void ImGui_ImplOpenGL3_RenderDrawData(ImDrawData* draw_data);

#ifdef __cplusplus
}
#endif
