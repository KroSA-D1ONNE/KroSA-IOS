#include "KroSA_RenderWareCoreBridge.h"
#include <dlfcn.h>
#include <cmath>

#define RW_GL3
#define LIBRW_EAGL
#include "rw.h"

extern "C" void krosaResetGL3DrawDiagnostics(void);
extern "C" int krosaGetGL3DrawDiagnostics(void);
extern "C" int krosaGetGL3DrawPixel(int);
extern "C" int krosaGetGL3DrawFramebuffer(void);
extern "C" int krosaGetGL3DrawViewport(int);
static int krosaLastGeometryDrawFlags = 0;
static int krosaLastGeometryInitStatus = 0;
static rw::Frame *krosaSceneFrame = nullptr;
static rw::Atomic *krosaSceneAtomic = nullptr;
static rw::gl3::ObjPipeline *krosaScenePipeline = nullptr;
static bool krosaSceneReady = false;

extern "C" void krosaLibrwGL3Shutdown(void) {
    // Called by UIViewRepresentable dismantling with the creating EAGL context current.
    if (krosaSceneAtomic) {
        krosaSceneAtomic->destroy();
        krosaSceneAtomic = nullptr;
    }
    if (krosaSceneFrame) {
        krosaSceneFrame->destroy();
        krosaSceneFrame = nullptr;
    }
    if (krosaScenePipeline) {
        krosaScenePipeline->destroy();
        krosaScenePipeline = nullptr;
    }
    krosaSceneReady = false;

    if (rw::Engine::state == rw::Engine::Started)
        rw::Engine::stop();
    if (rw::Engine::state == rw::Engine::Opened)
        rw::Engine::close();
    if (rw::Engine::state == rw::Engine::Initialized)
        rw::Engine::term();
}

extern "C" int krosaGetLastGeometryInitStatus(void) { return krosaLastGeometryInitStatus; }
extern "C" int krosaGetLastGeometryDrawFlags(void) { return krosaLastGeometryDrawFlags; }
extern "C" int krosaGetLastGeometryPixel(int i) { return krosaGetGL3DrawPixel(i); }
extern "C" int krosaGetLastGeometryFramebuffer(void) { return krosaGetGL3DrawFramebuffer(); }
extern "C" int krosaGetLastGeometryViewport(int i) { return krosaGetGL3DrawViewport(i); }
extern "C" int krosaGetGL3DrawMetric(int);
extern "C" int krosaGetLastGeometryMetric(int i) { return krosaGetGL3DrawMetric(i); }

extern "C" int krosaRenderWareCoreSmokeTest(void) {
    if (rw::Engine::state != rw::Engine::Dead) {
        return 0;
    }

    if (!rw::Engine::init()) {
        return 0;
    }

    const bool initialized = rw::Engine::state == rw::Engine::Initialized;
    rw::Engine::term();

    return initialized && rw::Engine::state == rw::Engine::Dead ? 1 : 0;
}

/// Checks the host-owned EAGL context before librw's GL loader is initialized.
extern "C" int krosaOpenGLESContextSmokeTest(void) {
    typedef const unsigned char *(*GetStringProc)(unsigned int);
    GetStringProc getString = reinterpret_cast<GetStringProc>(dlsym(RTLD_DEFAULT, "glGetString"));
    return getString != nullptr && getString(0x1F02) != nullptr ? 1 : 0;
}

/// Starts librw's actual GL3 device on the already-current EAGL context,
/// verifies that its shader pipeline initialized, then tears it down.
extern "C" int krosaLibrwGL3InitSmokeTest(int width, int height) {
    if (width <= 0 || height <= 0 ||
        rw::Engine::state != rw::Engine::Dead || rw::engine != nullptr) {
        return -1;
    }

    if (!rw::Engine::init()) {
        return -2;
    }

    rw::EngineOpenParams params;
    params.width = width;
    params.height = height;
    params.windowtitle = "KroSA iOS";

    if (!rw::Engine::open(&params)) {
        rw::Engine::term();
        return -3;
    }

    if (!rw::Engine::start()) {
        rw::Engine::close();
        rw::Engine::term();
        return -4;
    }

    const bool ready =
        rw::Engine::state == rw::Engine::Started &&
        rw::gl3::defaultShader != nullptr &&
        glGetString(GL_VERSION) != nullptr;

    rw::Engine::stop();
    rw::Engine::close();
    rw::Engine::term();

    return ready ? 1 : -5;
}

extern "C" int krosaLibrwGL3GeometrySmokeTest(int width, int height, float angleY, float angleX, float cameraDistance) {
    // The GL context, pipeline and GPU buffers belong to the lifetime of the
    // GLKView. Keep the test scene alive instead of allocating/freeing it on
    // every draw callback.
    krosaLastGeometryInitStatus = -1;
    if (width <= 0 || height <= 0)
        return -1;

    const bool needsEngineStart = rw::Engine::state == rw::Engine::Dead;
    if (!needsEngineStart &&
        (rw::Engine::state != rw::Engine::Started || rw::engine == nullptr))
        return -1;

    typedef void (*HostGetIntegervProc)(GLenum, GLint *);
    HostGetIntegervProc hostGetIntegerv =
        reinterpret_cast<HostGetIntegervProc>(dlsym(RTLD_DEFAULT, "glGetIntegerv"));
    if (!hostGetIntegerv)
        return -8;

    GLint hostFramebuffer = 0;
    GLint hostViewport[4] = {0, 0, 0, 0};
    hostGetIntegerv(GL_FRAMEBUFFER_BINDING, &hostFramebuffer);
    hostGetIntegerv(GL_VIEWPORT, hostViewport);
    if (hostFramebuffer == 0)
        return -7;

    if (needsEngineStart) {
        if (!rw::Engine::init()) {
            krosaLastGeometryInitStatus = -2;
            return -2;
        }
        rw::EngineOpenParams params;
        params.width = width;
        params.height = height;
        params.windowtitle = "KroSA Geometry Test";
        if (!rw::Engine::open(&params)) {
            krosaLastGeometryInitStatus = -3;
            rw::Engine::term();
            return -3;
        }
        if (!rw::Engine::start()) {
            krosaLastGeometryInitStatus = -4;
            rw::Engine::close();
            rw::Engine::term();
            return -4;
        }
    }

    krosaLastGeometryInitStatus =
        rw::Engine::state == rw::Engine::Started &&
        rw::gl3::defaultShader != nullptr && glGetString(GL_VERSION) != nullptr ? 1 : -5;
    if (krosaLastGeometryInitStatus != 1)
        return -5;

    if (!krosaSceneReady) {
        rw::Raster *textureRaster = rw::Raster::create(
            8, 8, 32, rw::Raster::TEXTURE | rw::Raster::C8888);
        rw::Texture *texture = textureRaster ? rw::Texture::create(textureRaster) : nullptr;
        if (textureRaster && !texture) {
            textureRaster->destroy();
            textureRaster = nullptr;
        }
        if (texture) {
            texture->setFilter(rw::Texture::NEAREST);
            texture->setAddressU(rw::Texture::CLAMP);
            texture->setAddressV(rw::Texture::CLAMP);
            rw::uint8 *texels = textureRaster->lock(
                0, rw::Raster::LOCKWRITE | rw::Raster::LOCKNOFETCH);
            if (texels) {
                for (int y = 0; y < 8; ++y) {
                    for (int x = 0; x < 8; ++x) {
                        const bool light = ((x / 2) + (y / 2)) % 2 == 0;
                        const size_t offset = (size_t(y) * 8 + size_t(x)) * 4;
                        texels[offset + 0] = light ? 35 : 5;
                        texels[offset + 1] = light ? 245 : 105;
                        texels[offset + 2] = light ? 65 : 20;
                        texels[offset + 3] = 255;
                    }
                }
                textureRaster->unlock(0);
            } else {
                texture->destroy();
                texture = nullptr;
            }
        }

        rw::Geometry *geometry = rw::Geometry::create(
            24, 12, rw::Geometry::POSITIONS | rw::Geometry::PRELIT);
        rw::Material *material = geometry ? rw::Material::create() : nullptr;
        bool built = false;

        if (geometry && material && texture) {
            material->color = {255, 255, 255, 255};
            material->setTexture(texture);
            texture->destroy();
            texture = nullptr;

            if (geometry->matList.appendMaterial(material) >= 0) {
                rw::MorphTarget *target = &geometry->morphTargets[0];
                const float facePositions[6][4][3] = {
                    {{-0.72f,-0.72f, 0.72f},{ 0.72f,-0.72f, 0.72f},{ 0.72f, 0.72f, 0.72f},{-0.72f, 0.72f, 0.72f}},
                    {{ 0.72f,-0.72f,-0.72f},{-0.72f,-0.72f,-0.72f},{-0.72f, 0.72f,-0.72f},{ 0.72f, 0.72f,-0.72f}},
                    {{ 0.72f,-0.72f, 0.72f},{ 0.72f,-0.72f,-0.72f},{ 0.72f, 0.72f,-0.72f},{ 0.72f, 0.72f, 0.72f}},
                    {{-0.72f,-0.72f,-0.72f},{-0.72f,-0.72f, 0.72f},{-0.72f, 0.72f, 0.72f},{-0.72f, 0.72f,-0.72f}},
                    {{-0.72f, 0.72f, 0.72f},{ 0.72f, 0.72f, 0.72f},{ 0.72f, 0.72f,-0.72f},{-0.72f, 0.72f,-0.72f}},
                    {{-0.72f,-0.72f,-0.72f},{ 0.72f,-0.72f,-0.72f},{ 0.72f,-0.72f, 0.72f},{-0.72f,-0.72f, 0.72f}}
                };
                const float faceUVs[4][2] = {
                    {0.0f,0.0f},{1.0f,0.0f},{1.0f,1.0f},{0.0f,1.0f}
                };
                for (int face = 0; face < 6; ++face) {
                    const int base = face * 4;
                    for (int corner = 0; corner < 4; ++corner) {
                        target->vertices[base + corner].set(
                            facePositions[face][corner][0],
                            facePositions[face][corner][1],
                            facePositions[face][corner][2]);
                        geometry->colors[base + corner] = {35, 245, 65, 255};
                        geometry->texCoords[0][base + corner] = {
                            faceUVs[corner][0], faceUVs[corner][1]};
                    }
                    const int tri = face * 2;
                    geometry->triangles[tri + 0].v[0] = base + 0;
                    geometry->triangles[tri + 0].v[1] = base + 1;
                    geometry->triangles[tri + 0].v[2] = base + 2;
                    geometry->triangles[tri + 0].matId = 0;
                    geometry->triangles[tri + 1].v[0] = base + 0;
                    geometry->triangles[tri + 1].v[1] = base + 2;
                    geometry->triangles[tri + 1].v[2] = base + 3;
                    geometry->triangles[tri + 1].matId = 0;
                }
                geometry->calculateBoundingSphere();
                geometry->unlock();

                krosaSceneFrame = rw::Frame::create();
                krosaSceneAtomic = rw::Atomic::create();
                krosaScenePipeline = rw::gl3::makeDefaultPipeline();
                if (krosaSceneFrame && krosaSceneAtomic && krosaScenePipeline && geometry->meshHeader) {
                    krosaSceneAtomic->setFrame(krosaSceneFrame);
                    krosaSceneAtomic->setGeometry(geometry, 0);
                    geometry->destroy(); // Atomic owns its retained geometry reference.
                    geometry = nullptr;
                    krosaSceneAtomic->pipeline = krosaScenePipeline;
                    built = true;
                }
            }
        }

        if (texture) texture->destroy();
        if (material) material->destroy();
        if (geometry) geometry->destroy();
        krosaSceneReady = built;
        if (!krosaSceneReady) {
            if (krosaSceneAtomic) { krosaSceneAtomic->destroy(); krosaSceneAtomic = nullptr; }
            if (krosaSceneFrame) { krosaSceneFrame->destroy(); krosaSceneFrame = nullptr; }
            if (krosaScenePipeline) { krosaScenePipeline->destroy(); krosaScenePipeline = nullptr; }
            return -6;
        }
    }

    const float aspect = float(width) / float(height);
    const float f = 1.0f / 0.57735026919f;
    const float nearPlane = 0.1f;
    const float farPlane = 100.0f;
    const float projection[16] = {
        f / aspect, 0, 0, 0,
        0, f, 0, 0,
        0, 0, (farPlane + nearPlane) / (nearPlane - farPlane), -1,
        0, 0, (2.0f * farPlane * nearPlane) / (nearPlane - farPlane), 0
    };
    const float cy = cosf(angleY), sy = sinf(angleY);
    const float cx = cosf(angleX), sx = sinf(angleX);
    const float view[16] = {
        cy, sx * sy, -cx * sy, 0,
        0, cx, sx, 0,
        sy, -sx * cy, cx * cy, 0,
        0, 0, -cameraDistance, 1
    };
    rw::gl3::setProjectionMatrix(const_cast<float*>(projection));
    rw::gl3::setViewMatrix(const_cast<float*>(view));

    glBindFramebuffer(GL_FRAMEBUFFER, (GLuint)hostFramebuffer);
    glViewport(hostViewport[0], hostViewport[1], hostViewport[2], hostViewport[3]);
    const GLenum framebufferStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    int result = -100 - (int)framebufferStatus;
    if (framebufferStatus == GL_FRAMEBUFFER_COMPLETE) {
        rw::SetRenderState(rw::ZTESTENABLE, 1);
        rw::SetRenderState(rw::ZWRITEENABLE, 1);
        rw::SetRenderState(rw::CULLMODE, rw::CULLNONE);
        rw::SetRenderState(rw::FOGENABLE, 0);
        rw::SetRenderState(rw::VERTEXALPHA, 0);
        while (glGetError() != GL_NO_ERROR) {}
        rw::SetRenderState(rw::FOGCOLOR, 0xFFFFFFFF);
        krosaResetGL3DrawDiagnostics();
        krosaSceneAtomic->render();
        krosaLastGeometryDrawFlags = krosaGetGL3DrawDiagnostics();
        glFinish();

        const GLenum drawError = glGetError();
        const GLint sampleX = hostViewport[0] + hostViewport[2] / 2;
        const GLint sampleY = hostViewport[1] + hostViewport[3] / 2;
        GLubyte centerPixel[4] = {0, 0, 0, 0};
        glReadPixels(sampleX, sampleY, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, centerPixel);
        const GLenum readError = glGetError();
        const bool greenPixel =
            centerPixel[1] > centerPixel[0] + 35 && centerPixel[1] > centerPixel[2] + 20;

        // Do not treat GL_CURRENT_PROGRAM or buffer bindings as draw-success
        // criteria: librw's GL3 pipeline may legitimately unbind them after
        // submission. The GL error state and sampled output are the meaningful
        // checks here; the detailed pipeline diagnostics remain available above.
        if (drawError != GL_NO_ERROR)
            result = -2100 - (int)drawError;
        else if (readError != GL_NO_ERROR)
            result = -2200 - (int)readError;
        else
            result = greenPixel ? 1 :
                -(1000 + centerPixel[0] * 65536 + centerPixel[1] * 256 + centerPixel[2]);
    }

    glBindFramebuffer(GL_FRAMEBUFFER, (GLuint)hostFramebuffer);
    glViewport(hostViewport[0], hostViewport[1], hostViewport[2], hostViewport[3]);
    glFlush();
    return result;
}
