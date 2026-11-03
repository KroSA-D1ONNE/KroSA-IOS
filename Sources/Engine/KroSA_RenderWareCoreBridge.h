#ifndef KROSA_RENDERWARE_CORE_BRIDGE_H
#define KROSA_RENDERWARE_CORE_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

const char *krosaGetEAGLShaderError(void);
/// Initializes and cleanly terminates the upstream RenderWare core.
/// Returns 1 when the core reaches Initialized and returns to Dead; 0 on failure.
int krosaRenderWareCoreSmokeTest(void);

/// Returns 1 when the current app-owned OpenGL ES context is callable from C++.
int krosaOpenGLESContextSmokeTest(void);

/// Initializes and shuts down librw GL3 using the current host-owned EAGL context.
/// Returns 1 on success, or a negative stage-specific error code.
int krosaLibrwGL3InitSmokeTest(int width, int height);

/// Builds and draws a triangle through librw Geometry + the GL3 object pipeline,
/// within the same Engine/EAGL lifecycle. Query init status after the call.
int krosaLibrwGL3GeometrySmokeTest(int width, int height, float angleY, float angleX, float cameraDistance);
/// Releases the test scene and GL3 device while the owning EAGL context is current.
void krosaLibrwGL3Shutdown(void);
/// Sets the optional user-provided DFF path; the file is streamed only after GL3 is ready.
void krosaLibrwGL3SetDFFPath(const char *path);
/// Sets newline-separated TXD paths; dictionaries are merged before the DFF is streamed.
void krosaLibrwGL3SetTXDPaths(const char *paths);
int krosaGetLastGeometryInitStatus(void);
/// EAGL backend stage: -1 loader failed, -2 no GL version, -3 GL3 init failed, 2 ready.
int krosaGetLastEAGLInitStatus(void);
/// DFF load status: 1 loaded, negative stream/path error, positive validation code otherwise.
int krosaGetLastDFFValidationStatus(void);
void krosaGetTXDDiagnostics(int *paths, int *opened, int *chunks, int *dicts, int *textures);

/// Bit flags captured inside librw defaultRenderCB before/after glDrawElements.
int krosaGetLastGeometryDrawFlags(void);
int krosaGetLastGeometryPixel(int component);
int krosaGetLastGeometryFramebuffer(void);
int krosaGetLastGeometryViewport(int component);
int krosaGetLastGeometryMetric(int metric);

#ifdef __cplusplus
}
#endif

#endif
