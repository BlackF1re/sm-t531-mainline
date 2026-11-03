// SPDX-License-Identifier: MIT
// Offscreen allocation probe. Counts private single-level RGBA targets through
// DRM fdinfo; presentation and shell configuration are never changed.
#define _POSIX_C_SOURCE 200809L
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static void require(int ok, const char *what)
{
    if (!ok) { fprintf(stderr, "%s failed\n", what); exit(1); }
}
static unsigned long memory_kib(void)
{
    DIR *directory = opendir("/proc/self/fdinfo");
    require(directory != NULL, "fdinfo directory");
    unsigned long maximum = 0;
    struct dirent *entry;
    while ((entry = readdir(directory))) {
        if (entry->d_name[0] == '.') continue;
        char path[512], line[512];
        snprintf(path, sizeof(path), "/proc/self/fdinfo/%s", entry->d_name);
        FILE *file = fopen(path, "r");
        if (!file) continue;
        while (fgets(line, sizeof(line), file)) {
            unsigned long value;
            if (sscanf(line, "drm-total-memory: %lu KiB", &value) == 1 && value > maximum)
                maximum = value;
        }
        fclose(file);
    }
    closedir(directory);
    return maximum; // duplicates of the same DRM client must not be summed
}
int main(int argc, char **argv)
{
    require(argc == 3, "usage: fd-texture-memory WIDTH HEIGHT");
    int width = atoi(argv[1]), height = atoi(argv[2]);
    require(width > 0 && width <= 1280 && height > 0 && height <= 1280, "dimensions");
    PFNEGLGETPLATFORMDISPLAYEXTPROC platform = (void *)eglGetProcAddress("eglGetPlatformDisplayEXT");
    require(platform != NULL, "platform display entry point");
    EGLDisplay display = platform(EGL_PLATFORM_SURFACELESS_MESA, EGL_DEFAULT_DISPLAY, NULL);
    require(eglInitialize(display, NULL, NULL), "EGL initialize");
    require(eglBindAPI(EGL_OPENGL_ES_API), "ES API");
    EGLint attributes[] = {EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_RENDERABLE_TYPE,
                          EGL_OPENGL_ES2_BIT, EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8,
                          EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8, EGL_NONE};
    EGLConfig config;
    EGLint count;
    require(eglChooseConfig(display, attributes, &config, 1, &count) && count, "EGL config");
    EGLint context_attributes[] = {EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE};
    EGLContext context = eglCreateContext(display, config, EGL_NO_CONTEXT, context_attributes);
    require(context != EGL_NO_CONTEXT, "ES context");
    require(eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, context), "surfaceless context");
    const char *renderer = (const char *)glGetString(GL_RENDERER);
    require(renderer && strstr(renderer, "FD305"), "FD305 hardware renderer");
    unsigned long before = memory_kib();
    enum { TARGETS = 16 };
    GLuint textures[TARGETS], framebuffer;
    glGenTextures(TARGETS, textures);
    glGenFramebuffers(1, &framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    for (int i = 0; i < TARGETS; i++) {
        glBindTexture(GL_TEXTURE_2D, textures[i]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, textures[i], 0);
        require(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE, "target completeness");
        glClearColor(0.25f, 0.5f, 0.75f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
    }
    glFinish();
    require(glGetError() == GL_NO_ERROR, "allocation and clears");
    unsigned long after = memory_kib();
    require(after > before, "DRM allocation accounting");
    printf("{\"renderer\":\"%s\",\"width\":%d,\"height\":%d,\"targets\":%d,\"before_kib\":%lu,\"after_kib\":%lu,\"increase_kib\":%lu}\n",
           renderer, width, height, TARGETS, before, after, after-before);
    glDeleteFramebuffers(1, &framebuffer);
    glDeleteTextures(TARGETS, textures);
    eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    eglDestroyContext(display, context);
    eglTerminate(display);
    return 0;
}
