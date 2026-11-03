// SPDX-License-Identifier: MIT
// Offscreen counterpart of fd2d-bench.c; no Activity, scanout or swap interval.
import android.opengl.EGL14;
import android.opengl.EGLConfig;
import android.opengl.EGLContext;
import android.opengl.EGLDisplay;
import android.opengl.EGLSurface;
import android.opengl.GLES20;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.util.Arrays;
import java.util.Locale;

public final class T531GpuBench {
    static void check(boolean ok, String message) {
        if (!ok) throw new IllegalStateException(message);
    }
    static int shader(int type, String source) {
        int object = GLES20.glCreateShader(type);
        GLES20.glShaderSource(object, source);
        GLES20.glCompileShader(object);
        int[] status = new int[1];
        GLES20.glGetShaderiv(object, GLES20.GL_COMPILE_STATUS, status, 0);
        check(status[0] != 0, GLES20.glGetShaderInfoLog(object));
        return object;
    }
    static int program(String mode) {
        int vs = shader(GLES20.GL_VERTEX_SHADER,
            "attribute vec2 pos; varying vec2 uv; uniform vec2 uvshift; void main(){uv=(pos+1.0)*0.5+uvshift;gl_Position=vec4(pos,0.,1.);}");
        int fs = shader(GLES20.GL_FRAGMENT_SHADER, mode.equals("solid") ?
            "precision mediump float; void main(){gl_FragColor=vec4(0.0,0.0,127.0/255.0,1.0)*0.7;}" :
            "precision mediump float; varying vec2 uv; uniform sampler2D tex; void main(){gl_FragColor=texture2D(tex,uv)*0.7;}");
        int p = GLES20.glCreateProgram();
        GLES20.glAttachShader(p, vs); GLES20.glAttachShader(p, fs);
        GLES20.glBindAttribLocation(p, 0, "pos"); GLES20.glLinkProgram(p);
        int[] status = new int[1];
        GLES20.glGetProgramiv(p, GLES20.GL_LINK_STATUS, status, 0);
        check(status[0] != 0, GLES20.glGetProgramInfoLog(p));
        GLES20.glDeleteShader(vs); GLES20.glDeleteShader(fs);
        return p;
    }
    static void run(int width, int height, String mode) {
        int p = program(mode);
        GLES20.glUseProgram(p);
        int shift = GLES20.glGetUniformLocation(p, "uvshift");
        if (shift >= 0) GLES20.glUniform2f(shift, 0, 0);
        FloatBuffer vertices = ByteBuffer.allocateDirect(32).order(ByteOrder.nativeOrder()).asFloatBuffer();
        vertices.put(new float[]{-1,-1, 1,-1, -1,1, 1,1}).position(0);
        GLES20.glVertexAttribPointer(0, 2, GLES20.GL_FLOAT, false, 0, vertices);
        GLES20.glEnableVertexAttribArray(0);
        ByteBuffer image = ByteBuffer.allocateDirect(width * height * 4);
        for (int i = 0; i < width * height; ++i)
            image.put((byte)(i*13)).put((byte)(i/width)).put((byte)127).put((byte)255);
        image.position(0);
        int[] textures = new int[2], fbo = new int[1];
        GLES20.glGenTextures(2, textures, 0);
        for (int i = 0; i < 2; ++i) {
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textures[i]);
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR);
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR);
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE);
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE);
            GLES20.glTexImage2D(GLES20.GL_TEXTURE_2D, 0, GLES20.GL_RGBA, width, height,
                0, GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, i == 0 ? image : null);
        }
        GLES20.glGenFramebuffers(1, fbo, 0);
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fbo[0]);
        GLES20.glFramebufferTexture2D(GLES20.GL_FRAMEBUFFER, GLES20.GL_COLOR_ATTACHMENT0,
            GLES20.GL_TEXTURE_2D, textures[1], 0);
        check(GLES20.glCheckFramebufferStatus(GLES20.GL_FRAMEBUFFER) == GLES20.GL_FRAMEBUFFER_COMPLETE, "FBO");
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textures[0]);
        GLES20.glViewport(0, 0, width, height);
        GLES20.glBlendFunc(GLES20.GL_ONE, GLES20.GL_ONE_MINUS_SRC_ALPHA);
        GLES20.glEnable(GLES20.GL_BLEND);
        GLES20.glClearColor(0, 0, 0, 1);
        int frames = 40;
        for (int layers : new int[]{1,2,4,8,16}) {
            double[] times = new double[frames];
            double sum = 0;
            for (int f = -5; f < frames; ++f) {
                long begin = System.nanoTime();
                GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT);
                for (int l = 0; l < layers; ++l) GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4);
                GLES20.glFinish();
                double ms = (System.nanoTime() - begin) / 1e6;
                check(GLES20.glGetError() == GLES20.GL_NO_ERROR, "GL render");
                if (f >= 0) { times[f] = ms; sum += ms; }
            }
            ByteBuffer pixel = ByteBuffer.allocateDirect(4);
            GLES20.glReadPixels(0, 0, 1, 1, GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, pixel);
            double blue = 0;
            for (int l = 0; l < layers; ++l) blue = (127.0/255.0)*0.7 + blue*0.3;
            int expected = (int)(blue*255 + 0.5), actual = pixel.get(2) & 255;
            check(Math.abs(actual - expected) <= 2, "Blue pixel " + actual + " expected " + expected);
            Arrays.sort(times);
            System.out.printf(Locale.US,
                "{\"width\":%d,\"height\":%d,\"shader_mode\":\"%s\",\"layers\":%d,\"blend\":1,\"clear_quad\":0,\"frames\":%d,\"mean_ms\":%.4f,\"p50_ms\":%.4f,\"p95_ms\":%.4f,\"blue\":%d}\n",
                width, height, mode, layers, frames, sum/frames, times[frames/2], times[(frames-1)*95/100], actual);
            System.out.flush();
        }
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0);
        GLES20.glDeleteFramebuffers(1, fbo, 0);
        GLES20.glDeleteTextures(2, textures, 0);
        GLES20.glDeleteProgram(p);
    }
    public static void main(String[] args) {
        EGLDisplay display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY);
        int[] version = new int[2];
        check(EGL14.eglInitialize(display, version, 0, version, 1), "EGL initialize");
        EGLConfig[] config = new EGLConfig[1]; int[] count = new int[1];
        int[] attributes = {EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT,
            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
            EGL14.EGL_RED_SIZE,8, EGL14.EGL_GREEN_SIZE,8, EGL14.EGL_BLUE_SIZE,8,
            EGL14.EGL_ALPHA_SIZE,8, EGL14.EGL_DEPTH_SIZE,0, EGL14.EGL_STENCIL_SIZE,0, EGL14.EGL_NONE};
        check(EGL14.eglChooseConfig(display, attributes, 0, config, 0, 1, count, 0) && count[0] > 0, "EGL config");
        EGLContext context = EGL14.eglCreateContext(display, config[0], EGL14.EGL_NO_CONTEXT,
            new int[]{EGL14.EGL_CONTEXT_CLIENT_VERSION,2,EGL14.EGL_NONE}, 0);
        check(context != EGL14.EGL_NO_CONTEXT, "EGL context");
        EGLSurface surface = EGL14.eglCreatePbufferSurface(display, config[0],
            new int[]{EGL14.EGL_WIDTH,1,EGL14.EGL_HEIGHT,1,EGL14.EGL_NONE}, 0);
        check(surface != EGL14.EGL_NO_SURFACE, "EGL pbuffer");
        check(EGL14.eglMakeCurrent(display, surface, surface, context), "EGL current");
        String renderer = GLES20.glGetString(GLES20.GL_RENDERER);
        check(renderer != null && renderer.contains("305"), "Adreno 305 required");
        System.out.println("{\"renderer\":\"" + renderer + "\",\"version\":\"" +
            GLES20.glGetString(GLES20.GL_VERSION) + "\",\"offscreen\":true,\"host\":\"Android Java GLES20 JNI\"}");
        try {
            for (int[] size : new int[][]{{1280,800},{640,400}})
                for (String mode : new String[]{"solid","sample"}) run(size[0], size[1], mode);
        } finally {
            EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT);
            EGL14.eglDestroySurface(display, surface); EGL14.eglDestroyContext(display, context);
            EGL14.eglTerminate(display);
        }
    }
}
