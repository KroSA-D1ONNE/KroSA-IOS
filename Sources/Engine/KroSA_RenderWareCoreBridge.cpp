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
