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
    (
        '\tdefaultShader = Shader::create(vs, fs);\n\tassert(defaultShader);\n\tdefaultShader_noAT = Shader::create(vs, fs_noAT);\n\tassert(defaultShader_noAT);\n\n\tdefaultShader_fullLight = Shader::create(vs_fullLight, fs);\n\tassert(defaultShader_fullLight);\n\tdefaultShader_fullLight_noAT = Shader::create(vs_fullLight, fs_noAT);\n\tassert(defaultShader_fullLight_noAT);',
        '\tkrosaEAGLInitStatus = -31;\n\tdefaultShader = Shader::create(vs, fs);\n\tif(!defaultShader) return 0;\n\tkrosaEAGLInitStatus = -32;\n\tdefaultShader_noAT = Shader::create(vs, fs_noAT);\n\tif(!defaultShader_noAT) return 0;\n\tkrosaEAGLInitStatus = -33;\n\tdefaultShader_fullLight = Shader::create(vs_fullLight, fs);\n\tif(!defaultShader_fullLight) return 0;\n\tkrosaEAGLInitStatus = -34;\n\tdefaultShader_fullLight_noAT = Shader::create(vs_fullLight, fs_noAT);\n\tif(!defaultShader_fullLight_noAT) return 0;\n\tkrosaEAGLInitStatus = -35;'
    )
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
