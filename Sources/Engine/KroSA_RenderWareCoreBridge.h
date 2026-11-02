#ifndef KROSA_RENDERWARE_CORE_BRIDGE_H
#define KROSA_RENDERWARE_CORE_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

/// Initializes and cleanly terminates the upstream RenderWare core.
/// Returns 1 when the core reaches Initialized and returns to Dead; 0 on failure.
int krosaRenderWareCoreSmokeTest(void);

#ifdef __cplusplus
}
#endif

#endif
