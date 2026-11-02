#ifndef KROSA_RENDERWARE_CORE_BRIDGE_H
#define KROSA_RENDERWARE_CORE_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

/// Initializes and cleanly terminates the upstream RenderWare core.
/// Returns 1 when the core reaches Initialized and returns to Dead; 0 on failure.
int krosaRenderWareCoreSmokeTest(void);

/// Returns 1 when the current app-owned OpenGL ES context is callable from C++.
int krosaOpenGLESContextSmokeTest(void);

/// Initializes and shuts down librw GL3 using the current host-owned EAGL context.
/// Returns 1 on success, or a negative stage-specific error code.
int krosaLibrwGL3InitSmokeTest(int width, int height);

/// Builds and draws a triangle through librw Geometry + the GL3 object pipeline.
int krosaLibrwGL3GeometrySmokeTest(int width, int height);

/// Bit flags captured inside librw defaultRenderCB before/after glDrawElements.
int krosaGetLastGeometryDrawFlags(void);
int krosaGetLastGeometryPixel(int component);
int krosaGetLastGeometryFramebuffer(void);
int krosaGetLastGeometryViewport(int component);

#ifdef __cplusplus
}
#endif

#endif
