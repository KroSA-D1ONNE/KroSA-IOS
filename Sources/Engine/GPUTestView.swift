import SwiftUI
import GLKit
import OpenGLES

/// Native GLES2 texture test. Uses an EAGLContext, a real GL texture,
/// UV coordinates and GLKBaseEffect's GLES shader pipeline.
struct GPUTestView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var renderWareStatus = "CORE SIN PROBAR"
    @State private var nativeGLStatus = "PUENTE C++ SIN PROBAR"
    @State private var librwGL3Status = "LIBRW GL3 / EAGL SIN PROBAR"
    @State private var geometryStatus = "GEOMETRÍA LIBRW SIN PROBAR"

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.045, blue: 0.04).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("KroSA · GRAPHICS TEST")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                GLES2TextureView(onContextValidated: { valid in
                    nativeGLStatus = valid ? "EAGL → C++: OK · GL CONTEXT ACTIVO" : "EAGL → C++: ERROR · SIN CONTEXTO"
                }, onGL3Initialized: { result in
                    librwGL3Status = result == 1 ? "LIBRW GL3 + EAGL: OK · SHADERS INICIALIZADOS" : "LIBRW GL3 + EAGL: ERROR · \(result)"
                }, onGeometryDrawn: { result in
                    if result == 1 {
                        geometryStatus = "LIBRW GEOMETRY: OK · TRIÁNGULO VERDE"
                    } else if result <= -1000 {
                        let packed = -result - 1000
                        let red = (packed >> 16) & 255
                        let green = (packed >> 8) & 255
                        let blue = packed & 255
                        let flags = krosaGetLastGeometryDrawFlags()
                        let reached = (flags & 128) != 0
                        let shader = (flags & 1) != 0
                        let vbo = (flags & 2) != 0
                        let ibo = (flags & 4) != 0
                        let position = (flags & 8) != 0
                        let attribBuffer = (flags & 16) != 0
                        let preDrawOK = (flags & 32) != 0
                        let drawOK = (flags & 64) != 0
                        let drawR = krosaGetLastGeometryPixel(0)
                        let drawG = krosaGetLastGeometryPixel(1)
                        let drawB = krosaGetLastGeometryPixel(2)
                        let fbo = krosaGetLastGeometryFramebuffer()
                        let vx = krosaGetLastGeometryViewport(2)
                        let vy = krosaGetLastGeometryViewport(3)
                        let readOK = (flags & 256) != 0
                        geometryStatus = "RGB:\(red),\(green),\(blue) CB:\(reached ? "Y" : "N") SH:\(shader ? "Y" : "N") VBO:\(vbo ? "Y" : "N") IBO:\(ibo ? "Y" : "N") POS:\(position ? "Y" : "N") AB:\(attribBuffer ? "Y" : "N") DRAW:\(drawOK ? "OK" : "ERR") INCB:\(drawR),\(drawG),\(drawB) FBO:\(fbo) VP:\(vx)x\(vy) READ:\(readOK ? "OK" : "ERR")"
                    } else {
                        geometryStatus = "LIBRW GEOMETRY: ERROR · \(result)"
                    }
                })
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.35), lineWidth: 1))

                Text("OpenGL ES 2.0 · EAGLContext · GL_TEXTURE_2D")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.green)

                Text("Cuadrilátero texturizado con UV. La textura se genera en memoria; no usa imágenes externas ni archivos de GTA.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)

                Text(nativeGLStatus)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(nativeGLStatus.contains("OK") ? .green : .orange)

                Text(librwGL3Status)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(librwGL3Status.contains("OK") ? .green : .orange)

                Text(geometryStatus)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(geometryStatus.contains("OK") ? .green : .orange)

                Button {
                    let result = krosaRenderWareCoreSmokeTest()
                    renderWareStatus = result == 1
                        ? "LIBRW CORE: OK · INIT / TERM"
                        : "LIBRW CORE: ERROR · \(result)"
                } label: {
                    Text("PROBAR LIBRW CORE")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.35, green: 0.95, blue: 0.48))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Text(renderWareStatus)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(renderWareStatus.contains("OK") ? .green : .orange)

                Button("VOLVER") { dismiss() }
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 13)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
    }
}

private struct GLES2TextureView: UIViewRepresentable {
    let onContextValidated: (Bool) -> Void
    let onGL3Initialized: (Int32) -> Void
    let onGeometryDrawn: (Int32) -> Void

    func makeCoordinator() -> Renderer { Renderer() }

    func makeUIView(context: Context) -> GLKView {
        context.coordinator.onContextValidated = onContextValidated
        context.coordinator.onGL3Initialized = onGL3Initialized
        context.coordinator.onGeometryDrawn = onGeometryDrawn
        let view = GLKView(frame: .zero, context: context.coordinator.glContext)
        view.delegate = context.coordinator
        view.drawableColorFormat = .RGBA8888
        view.drawableDepthFormat = .format16
        view.isOpaque = true
        view.enableSetNeedsDisplay = true
        view.setNeedsDisplay()
        return view
    }

    func updateUIView(_ uiView: GLKView, context: Context) {
        uiView.setNeedsDisplay()
    }

    final class Renderer: NSObject, GLKViewDelegate {
        let glContext: EAGLContext
        private var textureID: GLuint = 0
        private let effect = GLKBaseEffect()
        var onContextValidated: ((Bool) -> Void)?
        var onGL3Initialized: ((Int32) -> Void)?
        var onGeometryDrawn: ((Int32) -> Void)?
        private var didValidateNativeContext = false
        private var didRunLibrwGL3Test = false
        private var didRunGeometryTest = false

        override init() {
            glContext = EAGLContext(api: .openGLES2)!
            super.init()
            _ = EAGLContext.setCurrent(glContext)
            createTestTexture()
            effect.texture2d0.enabled = GLboolean(GL_TRUE)
            effect.texture2d0.name = textureID
            effect.texture2d0.envMode = .modulate
            effect.transform.projectionMatrix = GLKMatrix4MakeOrtho(-1, 1, -1, 1, -1, 1)
            effect.transform.modelviewMatrix = GLKMatrix4Identity
        }

        private func createTestTexture() {
            let width = 128
            let height = 128
            var pixels = [GLubyte](repeating: 255, count: width * height * 4)

            for y in 0..<height {
                for x in 0..<width {
                    let cell = ((x / 16) + (y / 16)) % 2 == 0
                    let offset = (y * width + x) * 4
                    pixels[offset] = cell ? 45 : 18
                    pixels[offset + 1] = cell ? 220 : 95
                    pixels[offset + 2] = cell ? 90 : 35
                    pixels[offset + 3] = 255
                }
            }

            glGenTextures(1, &textureID)
            glBindTexture(GLenum(GL_TEXTURE_2D), textureID)
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)

            pixels.withUnsafeBytes { bytes in
                glTexImage2D(
                    GLenum(GL_TEXTURE_2D), 0, GL_RGBA,
                    GLsizei(width), GLsizei(height), 0,
                    GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE),
                    bytes.baseAddress
                )
            }
            glBindTexture(GLenum(GL_TEXTURE_2D), 0)
        }

        func glkView(_ view: GLKView, drawIn rect: CGRect) {
            guard EAGLContext.setCurrent(glContext) else { return }
            if !didValidateNativeContext {
                didValidateNativeContext = true
                onContextValidated?(krosaOpenGLESContextSmokeTest() == 1)
            }
            if !didRunLibrwGL3Test {
                didRunLibrwGL3Test = true
                let result = krosaLibrwGL3InitSmokeTest(Int32(view.drawableWidth), Int32(view.drawableHeight))
                onGL3Initialized?(result)
            }

            glViewport(0, 0, GLsizei(view.drawableWidth), GLsizei(view.drawableHeight))
            glClearColor(0.025, 0.04, 0.03, 1.0)
            glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))

            // Interleaved position (XYZ) + texture coordinates (UV).
            let vertices: [GLfloat] = [
                -0.78, -0.68, 0,  0, 0,
                 0.78, -0.68, 0,  1, 0,
                -0.78,  0.68, 0,  0, 1,
                 0.78,  0.68, 0,  1, 1
            ]

            effect.prepareToDraw()
            vertices.withUnsafeBufferPointer { buffer in
                guard let base = buffer.baseAddress else { return }
                let stride = GLsizei(5 * MemoryLayout<GLfloat>.size)
                let position = GLuint(GLKVertexAttrib.position.rawValue)
                let texCoord = GLuint(GLKVertexAttrib.texCoord0.rawValue)

                glEnableVertexAttribArray(position)
                glEnableVertexAttribArray(texCoord)
                glVertexAttribPointer(position, 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, UnsafeRawPointer(base))
                glVertexAttribPointer(texCoord, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, UnsafeRawPointer(base.advanced(by: 3)))
                glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0, 4)
                glDisableVertexAttribArray(position)
                glDisableVertexAttribArray(texCoord)
            }

            if !didRunGeometryTest {
                didRunGeometryTest = true
                let result = krosaLibrwGL3GeometrySmokeTest(
                    Int32(view.drawableWidth), Int32(view.drawableHeight)
                )
                onGeometryDrawn?(result)
            }
        }

        deinit {
            if textureID != 0 {
                _ = EAGLContext.setCurrent(glContext)
                glDeleteTextures(1, &textureID)
            }
        }
    }
}
