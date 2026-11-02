#include "KroSA_RenderWareCoreBridge.h"
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
