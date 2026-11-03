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
     """static int\nstopGLFW(void)\n{\n\tglfwDestroyWindow(glGlobals.window);\n\treturn 1;\n}\n#elif defined(LIBRW_EAGL)\nstatic void *\nloadEAGLProc(const char *name)\n{\n\t// Desktop GL loaders may request ARB-suffixed entry points. On iOS\n\t// those aliases are not exported by OpenGL ES; resolve them to the\n\t// equivalent GLES core entry point instead of accepting a dead stub.\n\tsize_t length = strlen(name);\n\tif(length > 3 && strcmp(name + length - 3, "ARB") == 0){\n\t\tchar coreName[256];\n\t\tif(length - 3 < sizeof(coreName)){\n\t\t\tmemcpy(coreName, name, length - 3);\n\t\t\tcoreName[length - 3] = '\\0';\n\t\t\tvoid *coreProc = dlsym(RTLD_DEFAULT, coreName);\n\t\t\tif(coreProc) return coreProc;\n\t\t}\n\t}\n\treturn dlsym(RTLD_DEFAULT, name);\n}\n\nstatic int\nopenEAGL(EngineOpenParams *params)\n{\n\tif(params == nil || params->width <= 0 || params->height <= 0)\n\t\treturn 0;\n\tglGlobals.winWidth = params->width;\n\tglGlobals.winHeight = params->height;\n\tglGlobals.winTitle = params->windowtitle;\n\tglGlobals.presentWidth = params->width;\n\tglGlobals.presentHeight = params->height;\n\tglGlobals.presentOffX = 0;\n\tglGlobals.presentOffY = 0;\n\tglGlobals.numDisplays = 1;\n\tglGlobals.currentDisplay = 0;\n\tgl3Caps.gles = 1;\n\tgl3Caps.glversion = 20;\n\treturn 1;\n}\n\nstatic int closeEAGL(void) { return 1; }\n\nstatic int krosaEAGLInitStatus = 0;\nextern "C" int krosaGetEAGLInitStatus(void) { return krosaEAGLInitStatus; }\n\nstatic int\nstartEAGL(void)\n{\n\tkrosaEAGLInitStatus = -1;\n\tif(!gladLoadGLES2Loader(loadEAGLProc, 20)){\n\t\tRWERROR((ERR_GENERAL, "Unable to load OpenGL ES 2 entry points from the current EAGL context"));\n\t\treturn 0;\n\t}\n\tkrosaEAGLInitStatus = -2;\n\tif(glGetString(GL_VERSION) == nil) return 0;\n\tkrosaEAGLInitStatus = 1;\n\treturn 1;\n}\n\nstatic int stopEAGL(void) { return 1; }\n#else\n#error "Unsupported GL3 host backend"\n#endif"""),
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
     '#elif defined(LIBRW_EAGL)\nstatic int\ndeviceSystemEAGL(DeviceReq req, void *arg, int32 n)\n{\n\tswitch(req){\n\tcase DEVICEOPEN:\n\t\treturn openEAGL((EngineOpenParams*)arg);\n\tcase DEVICECLOSE:\n\t\treturn closeEAGL();\n\tcase DEVICEINIT:\n\t\tif(!startEAGL()) return 0;\n\t\tkrosaEAGLInitStatus = -3;\n\t\tif(!initOpenGL()) return 0;\n\t\tkrosaEAGLInitStatus = 2;\n\t\treturn 1;\n\tcase DEVICETERM:\n\t\treturn termOpenGL() && stopEAGL();\n\tcase DEVICEFINALIZE:\n\t\treturn finalizeOpenGL();\n\tcase DEVICEGETNUMSUBSYSTEMS:\n\t\treturn 1;\n\tcase DEVICEGETCURRENTSUBSYSTEM:\n\t\treturn 0;\n\tcase DEVICESETSUBSYSTEM:\n\t\treturn n == 0;\n\tcase DEVICEGETSUBSSYSTEMINFO:\n\t\tstrncpy(((SubSystemInfo*)arg)->name, "iOS EAGL", sizeof(SubSystemInfo::name));\n\t\treturn 1;\n\tcase DEVICEGETNUMVIDEOMODES:\n\t\treturn 1;\n\tcase DEVICEGETCURRENTVIDEOMODE:\n\t\treturn 0;\n\tcase DEVICESETVIDEOMODE:\n\t\treturn n == 0;\n\tcase DEVICEGETVIDEOMODEINFO: {\n\t\tVideoMode *mode = (VideoMode*)arg;\n\t\tmode->width = glGlobals.presentWidth;\n\t\tmode->height = glGlobals.presentHeight;\n\t\tmode->depth = 32;\n\t\tmode->flags = 0;\n\t\treturn 1;\n\t}\n\tcase DEVICEGETMAXMULTISAMPLINGLEVELS:\n\t\treturn 0;\n\tcase DEVICEGETMULTISAMPLINGLEVELS:\n\t\treturn 0;\n\tcase DEVICESETMULTISAMPLINGLEVELS:\n\t\treturn n == 0;\n\tdefault:\n\t\t// Unknown host queries must fail safely; never abort the iOS process.\n\t\treturn 0;\n\t}\n}\n#endif\n\nDevice renderdevice = {'),
    ('#elif defined(LIBRW_GLFW)\n\tgl3::deviceSystemGLFW\n#else\n\tnot implemented\n#endif',
     '#elif defined(LIBRW_GLFW)\n\tgl3::deviceSystemGLFW\n#elif defined(LIBRW_EAGL)\n\tgl3::deviceSystemEAGL\n#else\n#error "Unsupported GL3 device system"\n#endif')
])

edit("src/gl/gl3device.cpp", [
    ('\tdefaultShader = Shader::create(vs, fs);\n\tassert(defaultShader);\n\tdefaultShader_noAT = Shader::create(vs, fs_noAT);\n\tassert(defaultShader_noAT);\n\n\tdefaultShader_fullLight = Shader::create(vs_fullLight, fs);\n\tassert(defaultShader_fullLight);\n\tdefaultShader_fullLight_noAT = Shader::create(vs_fullLight, fs_noAT);\n\tassert(defaultShader_fullLight_noAT);',
     '\tkrosaEAGLInitStatus = -31;\n\tdefaultShader = Shader::create(vs, fs);\n\tif(!defaultShader) return 0;\n\tkrosaEAGLInitStatus = -32;\n\tdefaultShader_noAT = Shader::create(vs, fs_noAT);\n\tif(!defaultShader_noAT) return 0;\n\tkrosaEAGLInitStatus = -33;\n\tdefaultShader_fullLight = Shader::create(vs_fullLight, fs);\n\tif(!defaultShader_fullLight) return 0;\n\tkrosaEAGLInitStatus = -34;\n\tdefaultShader_fullLight_noAT = Shader::create(vs_fullLight, fs_noAT);\n\tif(!defaultShader_fullLight_noAT) return 0;\n\tkrosaEAGLInitStatus = -35;')
])

# Keep the failing GLSL stage separately; init status is overwritten with 2 on success.\n# 0=none, 1=vertex compile, 2=fragment compile, 3=program link.\n# Expose the exact failure stage inside Shader::create(). -311 = vertex compile,
# -312 = fragment compile, -313 = program link. This keeps the on-device probe
# useful without requiring access to the iOS device console.
edit("src/gl/gl3device.cpp", [
    ('extern "C" int krosaGetEAGLInitStatus(void) { return krosaEAGLInitStatus; }',
     'extern "C" int krosaGetEAGLInitStatus(void) { return krosaEAGLInitStatus; }\nextern "C" void krosaSetEAGLShaderStatus(int status) { krosaEAGLInitStatus = status; }')
])

edit("src/gl/gl3shader.cpp", [
    ('namespace gl3 {\n', 'namespace gl3 {\n\nstatic char krosaEAGLShaderError[2048] = {0};\nstatic int krosaEAGLShaderStage = 0;\nextern "C" void krosaSetEAGLShaderStatus(int status);\nextern "C" const char *krosaGetEAGLShaderError(void) { return krosaEAGLShaderError; }\nextern "C" int krosaGetEAGLShaderStage(void) { return krosaEAGLShaderStage; }\n'),
    ('GLint len;\n\tchar *log;\n\n\tfor(n = 0; src[n]; n++);',
     'GLint len;\n\tchar *log;\n\tkrosaEAGLShaderError[0] = 0;\n\n\tfor(n = 0; src[n]; n++);'),
    ('glGetShaderInfoLog(shdr, len, nil, log);',
     'glGetShaderInfoLog(shdr, len, nil, log);\n\t\tsnprintf(krosaEAGLShaderError, sizeof(krosaEAGLShaderError), "%s", log);'),
    ('glGetProgramInfoLog(prog, len, nil, log);',
     'glGetProgramInfoLog(prog, len, nil, log);\n\t\tsnprintf(krosaEAGLShaderError, sizeof(krosaEAGLShaderError), "%s", log);'),
    ('if(!success){\n\t\tprintShaderSource(src);',
     'if(!success){\n\t\tkrosaEAGLShaderStage = type == GL_VERTEX_SHADER ? 1 : 2;\n\t\tkrosaSetEAGLShaderStatus(type == GL_VERTEX_SHADER ? -311 : -312);\n\t\tprintShaderSource(src);'),
    ('if(!success){\n\t\tfprintf(stderr, "Error in program\\n");',
     'if(!success){\n\t\tkrosaEAGLShaderStage = 3;\n\t\tkrosaSetEAGLShaderStatus(-313);\n\t\tfprintf(stderr, "Error in program\\n");')
])

edit("src/engine.cpp", [
    ('\tengine->device.system(DEVICEOPEN, (void*)p, 0);\n\n\tengine->dummyDefaultPipeline = ObjPipeline::create();',
     '\tif(!engine->device.system(DEVICEOPEN, (void*)p, 0)){\n\t\trwFree(engine);\n\t\tengine = nil;\n\t\treturn 0;\n\t}\n\n\tengine->dummyDefaultPipeline = ObjPipeline::create();'),
    ('\tengine->device.system(DEVICEINIT, nil, 0);\n\n\tEngine::s_plglist.construct(engine);',
     '\tif(!engine->device.system(DEVICEINIT, nil, 0))\n\t\treturn 0;\n\n\tEngine::s_plglist.construct(engine);')
])


# OpenGL ES 2.0 requires GL_RGBA (not GL_RGBA8) as the texture internalformat.
# Upstream's GL3 raster path overrides C8888 with GL_RGBA8 even on GLES2,
# making glTexImage2D fail and leaving sampled textures black.
p = ROOT / "src/gl/gl3raster.cpp"
raster_source = p.read_text()
marker = "// glReadPixels only supports GL_RGBA"
pos = raster_source.find(marker)
if pos < 0:
    raise SystemExit("gl3raster.cpp: GLES texture format block not found")
format_pos = raster_source.find("natras->internalFormat = GL_RGBA8;", pos)
if format_pos < 0:
    raise SystemExit("gl3raster.cpp: GLES internalFormat assignment not found")
raster_source = raster_source[:format_pos] + raster_source[format_pos:].replace(
    "natras->internalFormat = GL_RGBA8;",
    "natras->internalFormat = GL_RGBA;", 1
)
p.write_text(raster_source)

# librw initializes fog values in resetRenderState(), but upstream forgets
# to mark them dirty. The registered uniforms therefore remain zero (black fog).
edit("src/gl/gl3device.cpp", [
    ("\tuniformState.fogColor = { 1.0f, 1.0f, 1.0f, 1.0f };",
     "\tuniformState.fogColor = { 1.0f, 1.0f, 1.0f, 1.0f };\n"
     "\tuniformStateDirty[RWGL_FOG] = true;\n"
     "\tuniformStateDirty[RWGL_FOGSTART] = true;\n"
     "\tuniformStateDirty[RWGL_FOGEND] = true;\n"
     "\tuniformStateDirty[RWGL_FOGCOLOR] = true;")
])


# EAGL shares a context with GLKView. UIKit/GLKView may change active texture
# units and bindings between frames, so librw's desktop-side binding cache is
# not authoritative on iOS. Always issue the actual GLES state calls.
edit("src/gl/gl3device.cpp", [
    ('\tif(activeTexture != n){\n\t\tactiveTexture = n;\n\t\tglActiveTexture(GL_TEXTURE0+n);\n\t}',
     '\tactiveTexture = n;\n\tglActiveTexture(GL_TEXTURE0+n);'),
    ('\tuint32 prev = boundTexture[activeTexture];\n\tif(prev != texid){\n\t\tboundTexture[activeTexture] = texid;\n\t\tglBindTexture(GL_TEXTURE_2D, texid);\n\t}\n\treturn prev;',
     '\tuint32 prev = boundTexture[activeTexture];\n\tboundTexture[activeTexture] = texid;\n\tglBindTexture(GL_TEXTURE_2D, texid);\n\treturn prev;')
])

# Keep upstream simple_fs_gl.inc unchanged: the next probe must sample real textures.
# Next isolate raw mesh vertex colors from librw's lighting/material pipeline.
# The previous on-device probe showed a green diffuse result, so bypass ambient,
# dynamic lighting and material multiplication while preserving in_color.
vertex_path = ROOT / "src/gl/shaders/default_vs_gl.inc"
vertex_shader = vertex_path.read_text()
lighting = '''"\tv_color = in_color;\\n"
"\tv_color.rgb += u_ambLight.rgb*surfAmbient;\\n"
"\tv_color.rgb += DoDynamicLight(Vertex.xyz, Normal)*surfDiffuse;\\n"
"\tv_color = clamp(v_color, 0.0, 1.0);\\n"
"\tv_color *= u_matColor;\\n"'''
raw_color = '\"\\tv_color = in_color;\\\\n\"'
if vertex_shader.count(lighting) != 1:
    raise SystemExit("default_vs_gl.inc: expected original vertex lighting block exactly once")
vertex_shader = vertex_shader.replace(lighting, raw_color, 1)
vertex_path.write_text(vertex_shader)

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
     """#include "rwgl3impl.h"
#include <vector>
static int krosaUVEnabled=-1, krosaUVBuffer=-1, krosaUVSize=-1, krosaUVStride=-1;
static int krosaTexBinding=-1, krosaSampler=-1, krosaActiveUnit=-1;
extern "C" void krosaGetTexturePathDiagnostics(int *uvEnabled,int *uvBuffer,int *uvSize,int *uvStride,int *textureBinding,int *sampler,int *activeUnit) {
 if(uvEnabled)*uvEnabled=krosaUVEnabled;
 if(uvBuffer)*uvBuffer=krosaUVBuffer;
 if(uvSize)*uvSize=krosaUVSize;
 if(uvStride)*uvStride=krosaUVStride;
 if(textureBinding)*textureBinding=krosaTexBinding;
 if(sampler)*sampler=krosaSampler;
 if(activeUnit)*activeUnit=krosaActiveUnit;
}

extern "C" {
static int krosaGL3DrawFlags = 0;
static int krosaGL3Pixel[3] = {0,0,0};
static int krosaGL3Framebuffer = 0;
static int krosaGL3Viewport[4] = {0,0,0,0};
static int krosaGL3IndexCount=-1, krosaGL3Primitive=-1, krosaGL3VertexCount=-1, krosaGL3MeshCount=-1, krosaGL3AttribCount=-1;
static int krosaGL3ColoredPixels=-1, krosaGL3MinX=-1, krosaGL3MinY=-1, krosaGL3MaxX=-1, krosaGL3MaxY=-1, krosaGL3BluePixels=-1, krosaGL3NonBlackPixels=-1, krosaGL3MaxGreen=-1, krosaGL3PreBluePixels=-1;
void krosaResetGL3DrawDiagnostics(void) { krosaGL3DrawFlags = 0; krosaGL3Pixel[0]=krosaGL3Pixel[1]=krosaGL3Pixel[2]=0; krosaGL3Framebuffer=0; krosaGL3IndexCount=krosaGL3Primitive=krosaGL3VertexCount=krosaGL3MeshCount=krosaGL3AttribCount=-1; krosaGL3ColoredPixels=krosaGL3MinX=krosaGL3MinY=krosaGL3MaxX=krosaGL3MaxY=krosaGL3BluePixels=krosaGL3NonBlackPixels=krosaGL3MaxGreen=krosaGL3PreBluePixels=-1; }
int krosaGetGL3DrawDiagnostics(void) { return krosaGL3DrawFlags; }
int krosaGetGL3DrawPixel(int i) { return i >= 0 && i < 3 ? krosaGL3Pixel[i] : -1; }
int krosaGetGL3DrawFramebuffer(void) { return krosaGL3Framebuffer; }
int krosaGetGL3DrawViewport(int i) { return i >= 0 && i < 4 ? krosaGL3Viewport[i] : -1; }
int krosaGetGL3DrawMetric(int i) { switch(i){case 0:return krosaGL3IndexCount;case 1:return krosaGL3Primitive;case 2:return krosaGL3VertexCount;case 3:return krosaGL3MeshCount;case 4:return krosaGL3AttribCount;case 5:return krosaGL3ColoredPixels;case 6:return krosaGL3MinX;case 7:return krosaGL3MinY;case 8:return krosaGL3MaxX;case 9:return krosaGL3MaxY;case 10:return krosaGL3BluePixels;case 11:return krosaGL3NonBlackPixels;case 12:return krosaGL3MaxGreen;case 13:return krosaGL3PreBluePixels;default:return -1;} }
}
"""),
    ('void\ndefaultRenderCB(Atomic *atomic, InstanceDataHeader *header)\n{',
     'void\ndefaultRenderCB(Atomic *atomic, InstanceDataHeader *header)\n{\n\tkrosaGL3DrawFlags |= 128;'),
    ('\t\tdrawInst(header, inst);',
     """\t\tkrosaGL3IndexCount = inst->numIndex;
\t\tkrosaGL3Primitive = header->primType;
\t\tkrosaGL3VertexCount = header->totalNumVertex;
\t\tkrosaGL3MeshCount = header->numMeshes;
\t\tkrosaGL3AttribCount = header->numAttribs;
\t\tGLint program = 0, arrayBuffer = 0, elementBuffer = 0;
\t\tGLint positionEnabled = 0, positionBuffer = 0;
\t\tglGetIntegerv(GL_CURRENT_PROGRAM, &program);
\t\tglGetIntegerv(GL_ARRAY_BUFFER_BINDING, &arrayBuffer);
\t\tglGetIntegerv(GL_ELEMENT_ARRAY_BUFFER_BINDING, &elementBuffer);
\t\tglGetVertexAttribiv(ATTRIB_POS, GL_VERTEX_ATTRIB_ARRAY_ENABLED, &positionEnabled);
\t\tglGetVertexAttribiv(ATTRIB_POS, GL_VERTEX_ATTRIB_ARRAY_BUFFER_BINDING, &positionBuffer);
\t\tif(program) krosaGL3DrawFlags |= 1;
\t\tif(arrayBuffer) krosaGL3DrawFlags |= 2;
\t\tif(elementBuffer) krosaGL3DrawFlags |= 4;
\t\tif(positionEnabled) krosaGL3DrawFlags |= 8;
\t\tif(positionBuffer) krosaGL3DrawFlags |= 16;
\t\tif(glGetError() == GL_NO_ERROR) krosaGL3DrawFlags |= 32;
\t\tdrawInst(header, inst);
\t\t// Single-pixel diagnostic only; full-frame readbacks stall the iPhone GPU.
		glGetIntegerv(GL_FRAMEBUFFER_BINDING, &krosaGL3Framebuffer);
		glGetIntegerv(GL_VIEWPORT, krosaGL3Viewport);
		GLubyte pixel[4] = {0,0,0,0};
		glReadPixels(glGlobals.presentWidth/2, glGlobals.presentHeight/2, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, pixel);
		krosaGL3Pixel[0]=pixel[0]; krosaGL3Pixel[1]=pixel[1]; krosaGL3Pixel[2]=pixel[2];
		if(glGetError() == GL_NO_ERROR) krosaGL3DrawFlags |= 256;""")
])

# Read back the actual GPU-side fog uniform after librw flushes it.
# Values are exposed as milli-units through the existing geometry metric API.
edit("src/gl/gl3render.cpp", [
    ('static int krosaGL3ColoredPixels=-1, krosaGL3MinX=-1, krosaGL3MinY=-1, krosaGL3MaxX=-1, krosaGL3MaxY=-1, krosaGL3BluePixels=-1, krosaGL3NonBlackPixels=-1, krosaGL3MaxGreen=-1, krosaGL3PreBluePixels=-1;',
     'static int krosaGL3ColoredPixels=-1, krosaGL3MinX=-1, krosaGL3MinY=-1, krosaGL3MaxX=-1, krosaGL3MaxY=-1, krosaGL3BluePixels=-1, krosaGL3NonBlackPixels=-1, krosaGL3MaxGreen=-1, krosaGL3PreBluePixels=-1;\nstatic GLfloat krosaGL3FogUniform[4] = {-1.0f,-1.0f,-1.0f,-1.0f};'),
    ('krosaGL3MaxGreen=krosaGL3PreBluePixels=-1; }',
     'krosaGL3MaxGreen=krosaGL3PreBluePixels=-1; krosaGL3FogUniform[0]=krosaGL3FogUniform[1]=krosaGL3FogUniform[2]=krosaGL3FogUniform[3]=-1.0f; }'),
    ('case 13:return krosaGL3PreBluePixels;default:return -1;',
     'case 13:return krosaGL3PreBluePixels;case 14:return (int)(krosaGL3FogUniform[0]*1000.0f);case 15:return (int)(krosaGL3FogUniform[1]*1000.0f);case 16:return (int)(krosaGL3FogUniform[2]*1000.0f);case 17:return (int)(krosaGL3FogUniform[3]*1000.0f);default:return -1;'),
    ("\t\tdrawInst(header, inst);\n\t\t// Single-pixel diagnostic only; full-frame readbacks stall the iPhone GPU.",
     "\t\tdrawInst(header, inst);\n\t\tif(program){ GLint fogLocation = glGetUniformLocation((GLuint)program, \"u_fogColor\"); if(fogLocation >= 0) glGetUniformfv((GLuint)program, fogLocation, krosaGL3FogUniform); }\n\t\t// Single-pixel diagnostic only; full-frame readbacks stall the iPhone GPU.")
])

# Replace upstream's complex default vertex shader with a minimal GLES 2
# compatible shader. This isolates EAGL compilation from desktop GLSL paths.
p = ROOT / "src/gl/shaders/header_vs.inc"
p.write_text(
    'const char *header_vert_src =\n'
    '"#define ATTRIB_POS 0\\n"\n'
    '"#define ATTRIB_COLOR 2\\n"\n'
    '"#define ATTRIB_TEXCOORDS0 5\\n"\n'
    '"attribute vec4 in_color;\\n"\n'
    '"attribute vec2 in_tex0;\\n"\n'
    '"uniform mat4 u_proj;\\n"\n'
    '"uniform mat4 u_view;\\n"\n'
    '"uniform mat4 u_world;\\n"\n'
    '"uniform vec4 u_matColor;\\n"\n'
    '"float DoFog(float depth) { return 0.0; }\\n"'
    ';\n'
)
p = ROOT / "src/gl/shaders/default_vs_gl.inc"
p.write_text(
    'const char *default_vert_src =\n'
    '"attribute vec3 in_pos;\\n"\n'
    '"varying vec4 v_color;\\n"\n'
    '"varying vec2 v_tex0;\\n"\n'
    '"varying float v_fog;\\n"\n'
    '"void main(void)\\n"\n'
    '"{\\n"\n'
    '"    gl_Position = u_proj * u_view * u_world * vec4(in_pos, 1.0);\\n"\n'
    '"    v_color = in_color;\\n"\n'
    '"    v_tex0 = in_tex0;\\n"\n'
    '"    v_fog = 0.0;\\n"\n'
    '"}\\n"\n'
    ';\n'
)


# Capture GLES texture-coordinate attribute and bound sampler state during setup.
edit("src/gl/gl3render.cpp", [
    ('setAttribPointers(header->attribDesc, header->numAttribs);',
     """setAttribPointers(header->attribDesc, header->numAttribs);
	GLint uvEnabled=0, uvBuffer=0, uvSize=0, uvStride=0, program=0, activeUnit=0, sampler=0;
	glGetVertexAttribiv(ATTRIB_TEXCOORDS0, GL_VERTEX_ATTRIB_ARRAY_ENABLED, &uvEnabled);
	glGetVertexAttribiv(ATTRIB_TEXCOORDS0, GL_VERTEX_ATTRIB_ARRAY_BUFFER_BINDING, &uvBuffer);
	glGetVertexAttribiv(ATTRIB_TEXCOORDS0, GL_VERTEX_ATTRIB_ARRAY_SIZE, &uvSize);
	glGetVertexAttribiv(ATTRIB_TEXCOORDS0, GL_VERTEX_ATTRIB_ARRAY_STRIDE, &uvStride);
	glGetIntegerv(GL_CURRENT_PROGRAM, &program);
	glGetIntegerv(GL_ACTIVE_TEXTURE, &activeUnit);
	glActiveTexture(GL_TEXTURE0);
	glGetIntegerv(GL_TEXTURE_BINDING_2D, &krosaTexBinding);
	if(program){ GLint loc=glGetUniformLocation((GLuint)program, "tex0"); if(loc>=0) glGetUniformiv((GLuint)program, loc, &sampler); }
	glActiveTexture((GLenum)activeUnit);
	krosaUVEnabled=uvEnabled; krosaUVBuffer=uvBuffer; krosaUVSize=uvSize; krosaUVStride=uvStride;
	krosaSampler=sampler; krosaActiveUnit=activeUnit;""")
])


# Trace TXD raster creation, CPU locking, and actual GPU upload separately.
edit("src/gl/gl3raster.cpp", [
    ('namespace gl3 {',
     'namespace gl3 {\\nstatic int krosaRasterCreateCount=0, krosaRasterLockCount=0, krosaRasterUnlockCount=0;\\nstatic int krosaUploadWidth=-1, krosaUploadHeight=-1, krosaUploadFormat=-1, krosaUploadError=-1;\\nextern "C" void krosaGetRasterUploadDiagnostics(int *w,int *h,int *format,int *error,int *created,int *locked,int *unlocked) { if(w)*w=krosaUploadWidth; if(h)*h=krosaUploadHeight; if(format)*format=krosaUploadFormat; if(error)*error=krosaUploadError; if(created)*created=krosaRasterCreateCount; if(locked)*locked=krosaRasterLockCount; if(unlocked)*unlocked=krosaRasterUnlockCount; }'),
    ('rasterCreateTexture(Raster *raster)\\n{',
     'rasterCreateTexture(Raster *raster)\\n{\\n\\tkrosaRasterCreateCount++; krosaUploadWidth=raster->width; krosaUploadHeight=raster->height; krosaUploadFormat=raster->format;'),
    ('rasterLock(Raster *raster, int32 level, int32 lockMode)\\n{',
     'rasterLock(Raster *raster, int32 level, int32 lockMode)\\n{\\n\\tkrosaRasterLockCount++;'),
    ('rasterUnlock(Raster *raster, int32 level)\\n{',
     'rasterUnlock(Raster *raster, int32 level)\\n{\\n\\tkrosaRasterUnlockCount++;'),
    ('raster->pixels);\\n\\t\\t\\t}',
     'raster->pixels);\\n\\t\\t\\t\\tif(level == 0){ krosaUploadWidth=raster->width; krosaUploadHeight=raster->height; krosaUploadFormat=natras->internalFormat; krosaUploadError=glGetError(); }\\n\\t\\t\\t}')
])
