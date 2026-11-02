#!/usr/bin/env python3
"""Apply the small, pinned iOS/EAGL host adaptation to upstream librw."""
from pathlib import Path

ROOT = Path("vendor/librw")

def edit(path, replacements):
    p = ROOT / path
    s = p.read_text()
    for old, new in replacements:
        count = s.count(old)
        if count != 1:
            raise SystemExit(f"{path}: expected one match, got {count}: {old[:90]!r}")
        s = s.replace(old, new, 1)
    p.write_text(s)

edit("CMakeLists.txt", [
    ('set(LIBRW_GL3_GFXLIBS "GLFW" "SDL2" "SDL3")',
     'set(LIBRW_GL3_GFXLIBS "GLFW" "SDL2" "SDL3" "EAGL")')
])

edit("src/CMakeLists.txt", [
    ('        target_link_libraries(librw\n            PUBLIC\n                SDL3::SDL3\n        )\n    endif()\n\n    set(OpenGL_GL_PREFERENCE GLVND)',
     '        target_link_libraries(librw\n            PUBLIC\n                SDL3::SDL3\n        )\n    elseif(LIBRW_GL3_GFXLIB STREQUAL "EAGL")\n        target_compile_definitions(librw PUBLIC LIBRW_EAGL)\n        target_link_libraries(librw PUBLIC "-framework OpenGLES")\n    endif()\n\n    if(NOT LIBRW_GL3_GFXLIB STREQUAL "EAGL")\n    set(OpenGL_GL_PREFERENCE GLVND)')
])

# Close the conditional around desktop OpenGL discovery.
p = ROOT / "src/CMakeLists.txt"
s = p.read_text()
old = '    endif()\nelseif(LIBRW_PLATFORM_D3D9)'
if s.count(old) != 1:
    raise SystemExit("src/CMakeLists.txt: cannot locate end of OpenGL discovery block")
s = s.replace(old, '    endif()\n    endif()\nelseif(LIBRW_PLATFORM_D3D9)', 1)
p.write_text(s)

edit("src/gl/rwgl3.h", [
    ('#elif defined(LIBRW_GLFW)\n#include <GLFW/glfw3.h>\n#else\n// sane fallback\n#define LIBRW_GLFW\n#include <GLFW/glfw3.h>\n#endif',
     '#elif defined(LIBRW_GLFW)\n#include <GLFW/glfw3.h>\n#elif defined(LIBRW_EAGL)\n// The host application owns and makes the EAGLContext current.\n#else\n#error "Select a supported librw GL3 host backend"\n#endif'),
    ('#elif defined(LIBRW_GLFW)\n\tGLFWwindow **window;\n#else\n    not implemented\n#endif\n\tint width, height;',
     '#elif defined(LIBRW_GLFW)\n\tGLFWwindow **window;\n#elif defined(LIBRW_EAGL)\n\t// EAGL context is supplied by the host app; only drawable dimensions are needed.\n#else\n#error "Unsupported GL3 host backend"\n#endif\n\tint width, height;')
])

edit("src/gl/rwgl3impl.h", [
    ('#elif defined(LIBRW_GLFW)\n\tGLFWvidmode mode;\n#else\n\tnot implemented\n#endif',
     '#elif defined(LIBRW_GLFW)\n\tGLFWvidmode mode;\n#elif defined(LIBRW_EAGL)\n\tint width, height;\n#else\n#error "Unsupported GL3 host backend"\n#endif'),
    ('#elif defined(LIBRW_GLFW)\n\tGLFWwindow **pWindow;\n\tGLFWwindow *window;\n\n\tGLFWmonitor *monitor;\n\tint numMonitors;\n\tint currentMonitor;\n#else\n\tnot implemented\n#endif',
     '#elif defined(LIBRW_GLFW)\n\tGLFWwindow **pWindow;\n\tGLFWwindow *window;\n\n\tGLFWmonitor *monitor;\n\tint numMonitors;\n\tint currentMonitor;\n#elif defined(LIBRW_EAGL)\n\tint numDisplays;\n\tint currentDisplay;\n#else\n#error "Unsupported GL3 host backend"\n#endif')
])

edit("src/gl/gl3device.cpp", [
    ('#include <assert.h>\n', '#include <assert.h>\n#ifdef LIBRW_EAGL\n#include <dlfcn.h>\n#include <string.h>\n#endif\n'),
    ('#elif defined(LIBRW_GLFW)\n\t\tglfwGetFramebufferSize(glGlobals.window, &r.w, &r.h);\n#else\n\t\tmissing implementation\n#endif',
     '#elif defined(LIBRW_GLFW)\n\t\tglfwGetFramebufferSize(glGlobals.window, &r.w, &r.h);\n#elif defined(LIBRW_EAGL)\n\t\tr.w = glGlobals.presentWidth;\n\t\tr.h = glGlobals.presentHeight;\n#else\n#error "Missing framebuffer dimensions for GL3 host"\n#endif'),
    ('\tglfwSwapBuffers(glGlobals.window);\n#else\n\tnot implemented\n#endif',
     '\tglfwSwapBuffers(glGlobals.window);\n#elif defined(LIBRW_EAGL)\n\t// GLKView owns presentation; its delegate presents after this draw callback.\n\t(void)raster;\n\t(void)flags;\n#else\n#error "Missing raster presentation for GL3 host"\n#endif'),
    ('static int\nstopGLFW(void)\n{\n\tglfwDestroyWindow(glGlobals.window);\n\treturn 1;\n}\n#else\nnot implemented\n#endif',
     """static int\nstopGLFW(void)\n{\n\tglfwDestroyWindow(glGlobals.window);\n\treturn 1;\n}\n#elif defined(LIBRW_EAGL)\nstatic void *\nloadEAGLProc(const char *name)\n{\n\t// Desktop GL loaders may request ARB-suffixed entry points. On iOS\n\t// those aliases are not exported by OpenGL ES; resolve them to the\n\t// equivalent GLES core entry point instead of accepting a dead stub.\n\tsize_t length = strlen(name);\n\tif(length > 3 && strcmp(name + length - 3, "ARB") == 0){\n\t\tchar coreName[256];\n\t\tif(length - 3 < sizeof(coreName)){\n\t\t\tmemcpy(coreName, name, length - 3);\n\t\t\tcoreName[length - 3] = '\\0';\n\t\t\tvoid *coreProc = dlsym(RTLD_DEFAULT, coreName);\n\t\t\tif(coreProc) return coreProc;\n\t\t}\n\t}\n\treturn dlsym(RTLD_DEFAULT, name);\n}\n\nstatic int\nopenEAGL(EngineOpenParams *params)\n{\n\tif(params == nil || params->width <= 0 || params->height <= 0)\n\t\treturn 0;\n\tglGlobals.winWidth = params->width;\n\tglGlobals.winHeight = params->height;\n\tglGlobals.winTitle = params->windowtitle;\n\tglGlobals.presentWidth = params->width;\n\tglGlobals.presentHeight = params->height;\n\tglGlobals.presentOffX = 0;\n\tglGlobals.presentOffY = 0;\n\tglGlobals.numDisplays = 1;\n\tglGlobals.currentDisplay = 0;\n\tgl3Caps.gles = 1;\n\tgl3Caps.glversion = 20;\n\treturn 1;\n}\n\nstatic int closeEAGL(void) { return 1; }\n\nstatic int\nstartEAGL(void)\n{\n\tif(!gladLoadGLES2Loader(loadEAGLProc, 20)){\n\t\tRWERROR((ERR_GENERAL, "Unable to load OpenGL ES 2 entry points from the current EAGL context"));\n\t\treturn 0;\n\t}\n\treturn glGetString(GL_VERSION) != nil;\n}\n\nstatic int stopEAGL(void) { return 1; }\n#else\n#error "Unsupported GL3 host backend"\n#endif"""),
    ('static void\nsetRasterStage(uint32 stage, Raster *raster)\n{\n\tbool32 alpha;\n\tif(raster != rwStateCache.texstage[stage].raster){',
     'static void\nsetRasterStage(uint32 stage, Raster *raster)\n{\n\tbool32 alpha;\n\t// A null texture must bind librw\'s white fallback even when the cache starts null.\n\tif(raster != rwStateCache.texstage[stage].raster || raster == nil){'),
    ('\tglGetFloatv(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, &gl3Caps.maxAnisotropy);',
     '\tgl3Caps.maxAnisotropy = 1.0f;\n\tif(GLAD_GL_EXT_texture_filter_anisotropic)\n\t\tglGetFloatv(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, &gl3Caps.maxAnisotropy);'),
    ('\tglGetFloatv(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, &maxAnisotropy);',
     '\tmaxAnisotropy = 1.0f;\n\tif(GLAD_GL_EXT_texture_filter_anisotropic)\n\t\tglGetFloatv(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, &maxAnisotropy);'),
    ('\t\t\t\tglTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAX_ANISOTROPY_EXT, (float)maxAniso);',
     '\t\t\t\tif(GLAD_GL_EXT_texture_filter_anisotropic)\n\t\t\t\t\tglTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAX_ANISOTROPY_EXT, (float)maxAniso);'),
    ('#elif defined(LIBRW_GLFW)\n\nstatic int\ndeviceSystemGLFW(DeviceReq req, void *arg, int32 n)',
     '#elif defined(LIBRW_GLFW)\n\nstatic int\ndeviceSystemGLFW(DeviceReq req, void *arg, int32 n)'),
    ('#else\n\nnot implemented\n\n#endif\n\nDevice renderdevice = {',
     '#elif defined(LIBRW_EAGL)\nstatic int\ndeviceSystemEAGL(DeviceReq req, void *arg, int32 n)\n{\n\tswitch(req){\n\tcase DEVICEOPEN:\n\t\treturn openEAGL((EngineOpenParams*)arg);\n\tcase DEVICECLOSE:\n\t\treturn closeEAGL();\n\tcase DEVICEINIT:\n\t\treturn startEAGL() && initOpenGL();\n\tcase DEVICETERM:\n\t\treturn termOpenGL() && stopEAGL();\n\tcase DEVICEFINALIZE:\n\t\treturn finalizeOpenGL();\n\tcase DEVICEGETNUMSUBSYSTEMS:\n\t\treturn 1;\n\tcase DEVICEGETCURRENTSUBSYSTEM:\n\t\treturn 0;\n\tcase DEVICESETSUBSYSTEM:\n\t\treturn n == 0;\n\tcase DEVICEGETSUBSSYSTEMINFO:\n\t\tstrncpy(((SubSystemInfo*)arg)->name, "iOS EAGL", sizeof(SubSystemInfo::name));\n\t\treturn 1;\n\tcase DEVICEGETNUMVIDEOMODES:\n\t\treturn 1;\n\tcase DEVICEGETCURRENTVIDEOMODE:\n\t\treturn 0;\n\tcase DEVICESETVIDEOMODE:\n\t\treturn n == 0;\n\tcase DEVICEGETVIDEOMODEINFO: {\n\t\tVideoMode *mode = (VideoMode*)arg;\n\t\tmode->width = glGlobals.presentWidth;\n\t\tmode->height = glGlobals.presentHeight;\n\t\tmode->depth = 32;\n\t\tmode->flags = 0;\n\t\treturn 1;\n\t}\n\tcase DEVICEGETMAXMULTISAMPLINGLEVELS:\n\t\treturn 0;\n\tcase DEVICEGETMULTISAMPLINGLEVELS:\n\t\treturn 0;\n\tcase DEVICESETMULTISAMPLINGLEVELS:\n\t\treturn n == 0;\n\tdefault:\n\t\t// Unknown host queries must fail safely; never abort the iOS process.\n\t\treturn 0;\n\t}\n}\n#endif\n\nDevice renderdevice = {'),
    ('#elif defined(LIBRW_GLFW)\n\tgl3::deviceSystemGLFW\n#else\n\tnot implemented\n#endif',
     '#elif defined(LIBRW_GLFW)\n\tgl3::deviceSystemGLFW\n#elif defined(LIBRW_EAGL)\n\tgl3::deviceSystemEAGL\n#else\n#error "Unsupported GL3 device system"\n#endif')
])

edit("src/gl/gl3device.cpp", [
    ('\tdefaultShader = Shader::create(vs, fs);\n\tassert(defaultShader);\n\tdefaultShader_noAT = Shader::create(vs, fs_noAT);\n\tassert(defaultShader_noAT);\n\n\tdefaultShader_fullLight = Shader::create(vs_fullLight, fs);\n\tassert(defaultShader_fullLight);\n\tdefaultShader_fullLight_noAT = Shader::create(vs_fullLight, fs_noAT);\n\tassert(defaultShader_fullLight_noAT);',
     '\tdefaultShader = Shader::create(vs, fs);\n\tdefaultShader_noAT = Shader::create(vs, fs_noAT);\n\tdefaultShader_fullLight = Shader::create(vs_fullLight, fs);\n\tdefaultShader_fullLight_noAT = Shader::create(vs_fullLight, fs_noAT);\n\tif(!defaultShader || !defaultShader_noAT || !defaultShader_fullLight || !defaultShader_fullLight_noAT){\n\t\tif(defaultShader) defaultShader->destroy();\n\t\tif(defaultShader_noAT) defaultShader_noAT->destroy();\n\t\tif(defaultShader_fullLight) defaultShader_fullLight->destroy();\n\t\tif(defaultShader_fullLight_noAT) defaultShader_fullLight_noAT->destroy();\n\t\tdefaultShader = defaultShader_noAT = defaultShader_fullLight = defaultShader_fullLight_noAT = nil;\n\t\tglDeleteTextures(1, &whitetex);\n\t\twhitetex = 0;\n\t\treturn 0;\n\t}')
])

edit("src/engine.cpp", [
    ('\tengine->device.system(DEVICEOPEN, (void*)p, 0);\n\n\tengine->dummyDefaultPipeline = ObjPipeline::create();',
     '\tif(!engine->device.system(DEVICEOPEN, (void*)p, 0)){\n\t\trwFree(engine);\n\t\tengine = nil;\n\t\treturn 0;\n\t}\n\n\tengine->dummyDefaultPipeline = ObjPipeline::create();'),
    ('\tengine->device.system(DEVICEINIT, nil, 0);\n\n\tEngine::s_plglist.construct(engine);',
     '\tif(!engine->device.system(DEVICEINIT, nil, 0))\n\t\treturn 0;\n\n\tEngine::s_plglist.construct(engine);')
])

print("Applied iOS EAGL host patch to pinned librw source")

# Instrument the actual GL3 draw callback, while its shader, VBO, IBO and
# vertex attribute bindings are still active. These flags are consumed by the
# host bridge after Atomic::render() returns.
edit("src/gl/gl3render.cpp", [
    ('\t\tif((vsBits & VSLIGHT_MASK) == 0){',
     '\t\t// Reset host GLKView raster state before librw submits geometry.\n\t\tglDisable(GL_SCISSOR_TEST);\n\t\tglDisable(GL_DEPTH_TEST);\n\t\tglDisable(GL_CULL_FACE);\n\t\tglDisable(GL_BLEND);\n\t\tglDisable(GL_STENCIL_TEST);\n\t\tglColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);\n\t\tglDepthMask(GL_TRUE);\n\t\tglViewport(0, 0, glGlobals.presentWidth, glGlobals.presentHeight);\n\t\tif((vsBits & VSLIGHT_MASK) == 0){')
])

edit("src/gl/gl3render.cpp", [
    ('#include "rwgl3impl.h"\n',
     '#include "rwgl3impl.h"\n\nextern "C" {\nstatic int krosaGL3DrawFlags = 0;\nstatic int krosaGL3Pixel[3] = {0,0,0};\nstatic int krosaGL3Framebuffer = 0;\nstatic int krosaGL3Viewport[4] = {0,0,0,0};\nvoid krosaResetGL3DrawDiagnostics(void) { krosaGL3DrawFlags = 0; krosaGL3Pixel[0]=krosaGL3Pixel[1]=krosaGL3Pixel[2]=0; krosaGL3Framebuffer=0; }\nint krosaGetGL3DrawDiagnostics(void) { return krosaGL3DrawFlags; }\nint krosaGetGL3DrawPixel(int i) { return i >= 0 && i < 3 ? krosaGL3Pixel[i] : -1; }\nint krosaGetGL3DrawFramebuffer(void) { return krosaGL3Framebuffer; }\nint krosaGetGL3DrawViewport(int i) { return i >= 0 && i < 4 ? krosaGL3Viewport[i] : -1; }\nstatic int krosaGL3IndexCount=0, krosaGL3Primitive=0, krosaGL3VertexCount=0, krosaGL3MeshCount=0, krosaGL3AttribCount=0;\nint krosaGetGL3DrawMetric(int i) { switch(i){case 0:return krosaGL3IndexCount;case 1:return krosaGL3Primitive;case 2:return krosaGL3VertexCount;case 3:return krosaGL3MeshCount;case 4:return krosaGL3AttribCount;default:return -1;} }\n}\n'),
    ('void\ndefaultRenderCB(Atomic *atomic, InstanceDataHeader *header)\n{',
     'void\ndefaultRenderCB(Atomic *atomic, InstanceDataHeader *header)\n{\n\tkrosaGL3DrawFlags |= 128;'),
    ('\t\tdrawInst(header, inst);',
     '\t\tkrosaGL3IndexCount = inst->numIndex;\n\t\tkrosaGL3Primitive = header->primType;\n\t\tkrosaGL3VertexCount = header->totalNumVertex;\n\t\tkrosaGL3MeshCount = header->numMeshes;\n\t\tkrosaGL3AttribCount = header->numAttribs;\n\t\tGLint program = 0, arrayBuffer = 0, elementBuffer = 0;\n\t\tGLint positionEnabled = 0, positionBuffer = 0;\n\t\tglGetIntegerv(GL_CURRENT_PROGRAM, &program);\n\t\tglGetIntegerv(GL_ARRAY_BUFFER_BINDING, &arrayBuffer);\n\t\tglGetIntegerv(GL_ELEMENT_ARRAY_BUFFER_BINDING, &elementBuffer);\n\t\tglGetVertexAttribiv(ATTRIB_POS, GL_VERTEX_ATTRIB_ARRAY_ENABLED, &positionEnabled);\n\t\tglGetVertexAttribiv(ATTRIB_POS, GL_VERTEX_ATTRIB_ARRAY_BUFFER_BINDING, &positionBuffer);\n\t\tif(program) krosaGL3DrawFlags |= 1;\n\t\tif(arrayBuffer) krosaGL3DrawFlags |= 2;\n\t\tif(elementBuffer) krosaGL3DrawFlags |= 4;\n\t\tif(positionEnabled) krosaGL3DrawFlags |= 8;\n\t\tif(positionBuffer) krosaGL3DrawFlags |= 16;\n\t\tif(glGetError() == GL_NO_ERROR) krosaGL3DrawFlags |= 32;\n\t\tdrawInst(header, inst);\n\t\tif(glGetError() == GL_NO_ERROR) krosaGL3DrawFlags |= 64;\n\t\tglGetIntegerv(GL_FRAMEBUFFER_BINDING, &krosaGL3Framebuffer);\n\t\tglGetIntegerv(GL_VIEWPORT, krosaGL3Viewport);\n\t\tGLubyte pixel[4] = {0,0,0,0};\n\t\tglReadPixels(glGlobals.presentWidth/2, glGlobals.presentHeight/2, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, pixel);\n\t\tkrosaGL3Pixel[0]=pixel[0]; krosaGL3Pixel[1]=pixel[1]; krosaGL3Pixel[2]=pixel[2];\n\t\tif(glGetError() == GL_NO_ERROR) krosaGL3DrawFlags |= 256;')
])
