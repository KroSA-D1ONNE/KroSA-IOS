#include "KroSA_RenderWareCoreBridge.h"
#include <dlfcn.h>

#define RW_GL3
#define LIBRW_EAGL
#include "rw.h"

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

extern "C" int krosaLibrwGL3GeometrySmokeTest(int width, int height) {
    if (width <= 0 || height <= 0 ||
        rw::Engine::state != rw::Engine::Dead || rw::engine != nullptr)
        return -1;
    if (!rw::Engine::init())
        return -2;

    rw::EngineOpenParams params;
    params.width = width;
    params.height = height;
    params.windowtitle = "KroSA Geometry Test";
    if (!rw::Engine::open(&params)) {
        rw::Engine::term();
        return -3;
    }
    if (!rw::Engine::start()) {
        rw::Engine::close();
        rw::Engine::term();
        return -4;
    }

    int result = -5;
    rw::Geometry *geometry = rw::Geometry::create(
        3, 1, rw::Geometry::POSITIONS | rw::Geometry::PRELIT | rw::Geometry::MODULATE);
    rw::Material *material = nullptr;
    rw::Frame *frame = nullptr;
    rw::Atomic *atomic = nullptr;
    rw::gl3::ObjPipeline *pipeline = nullptr;

    if (geometry) {
        material = rw::Material::create();
        if (material) material->color = {45, 235, 95, 255};
        if (material && geometry->matList.appendMaterial(material) == 0) {
            material->destroy();
            material = nullptr;

            rw::MorphTarget *target = &geometry->morphTargets[0];
            target->vertices[0].set(-0.62f, -0.58f, 0.0f);
            target->vertices[1].set( 0.62f, -0.58f, 0.0f);
            target->vertices[2].set( 0.00f,  0.66f, 0.0f);
            geometry->colors[0] = {45, 235, 95, 255};
            geometry->colors[1] = {20, 150, 65, 255};
            geometry->colors[2] = {110, 255, 145, 255};
            geometry->triangles[0].v[0] = 0;
            geometry->triangles[0].v[1] = 1;
            geometry->triangles[0].v[2] = 2;
            geometry->triangles[0].matId = 0;
            geometry->calculateBoundingSphere();
            geometry->unlock();

            frame = rw::Frame::create();
            atomic = rw::Atomic::create();
            pipeline = rw::gl3::makeDefaultPipeline();
            if (frame && atomic && pipeline && geometry->meshHeader) {
                atomic->setFrame(frame);
                atomic->setGeometry(geometry, 0);
                geometry->destroy();
                geometry = nullptr;
                atomic->pipeline = pipeline;

                const float identity[16] = {
                    1, 0, 0, 0, 0, 1, 0, 0,
                    0, 0, 1, 0, 0, 0, 0, 1
                };
                rw::gl3::setProjectionMatrix(const_cast<float*>(identity));
                rw::gl3::setViewMatrix(const_cast<float*>(identity));
                glViewport(0, 0, width, height);
                rw::SetRenderState(rw::ZTESTENABLE, 0);
                rw::SetRenderState(rw::ZWRITEENABLE, 0);
                rw::SetRenderState(rw::CULLMODE, rw::CULLNONE);
                rw::SetRenderState(rw::FOGENABLE, 0);
                rw::SetRenderState(rw::VERTEXALPHA, 0);
                atomic->render();
                glFinish();
                GLubyte centerPixel[4] = {0, 0, 0, 0};
                glReadPixels(width / 2, height / 2, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, centerPixel);
                const GLenum renderError = glGetError();
                const bool greenPixel = centerPixel[1] > centerPixel[0] + 35 && centerPixel[1] > centerPixel[2] + 20;
                // Preserve the sampled RGB in the error code to diagnose the exact output.
                result = renderError != GL_NO_ERROR ? -6 :
                    (greenPixel ? 1 : -(1000 + centerPixel[0] * 65536 + centerPixel[1] * 256 + centerPixel[2]));
            }
        }
    }

    if (material) material->destroy();
    if (geometry) geometry->destroy();
    if (atomic) atomic->destroy();
    if (frame) frame->destroy();
    if (pipeline) pipeline->destroy();

    rw::Engine::stop();
    rw::Engine::close();
    rw::Engine::term();
    return result;
}
