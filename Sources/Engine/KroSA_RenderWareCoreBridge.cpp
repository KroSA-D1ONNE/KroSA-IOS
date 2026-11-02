#include "KroSA_RenderWareCoreBridge.h"
#include "rw.h"
#include <OpenGLES/ES2/gl.h>

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

/// Confirms that the app-owned EAGL context is current and callable from C++.
extern "C" int krosaOpenGLESContextSmokeTest(void) {
    const GLubyte *version = glGetString(GL_VERSION);
    return version != nullptr ? 1 : 0;
}
