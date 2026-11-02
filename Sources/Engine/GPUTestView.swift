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
    @State private var isRunningGPU = false

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.045, blue: 0.04).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("KroSA · GRAPHICS TEST")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                if isRunningGPU {
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
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "gpu")
                            .font(.system(size: 42, weight: .light))
                            .foregroundStyle(.green)
                        Text("PRUEBA EAGL PREPARADA")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        Text("El motor gráfico se iniciará únicamente cuando pulses el botón. Así la pantalla de diagnóstico no crea un contexto GL al abrirse.")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                        Button("INICIAR PRUEBA EAGL") { isRunningGPU = true }
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .padding(18)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.35), lineWidth: 1))
                }

                Text("OpenGL ES 2.0 · EAGLContext · GL_TEXTURE_2D")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.green)

                Text("El fondo cuadriculado valida OpenGL ES nativo. El triángulo verde lo dibuja librw GL3/EAGL con un material sin textura: comprueba también el enlace de la textura blanca de reemplazo.")
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

    func makeUIView(context: Context) -> UIView {
        context.coordinator.onContextValidated = onContextValidated
        context.coordinator.onGL3Initialized = onGL3Initialized
        context.coordinator.onGeometryDrawn = onGeometryDrawn

        #if targetEnvironment(simulator)
        // The hosted macOS simulator crashes in its GLKit/GLES dispatch (null function
        // pointer) before the renderer can run. Keep simulator CI UI-only; the real
        // EAGL/librw path below is compiled and used on physical iOS devices.
        let label = UILabel()
        label.text = "GPU REAL OMITIDA EN SIMULADOR CI\nLa prueba EAGL / librw debe ejecutarse en un iPhone físico."
        label.textColor = .systemOrange
        label.textAlignment = .center
        label.numberOfLines = 0
        // Defer SwiftUI state updates until makeUIView has returned.
        DispatchQueue.main.async {
            onContextValidated(false)
            onGL3Initialized(-91)
            onGeometryDrawn(-91)
        }
        return label
        #else
        guard let glContext = context.coordinator.glContext else {
            let label = UILabel()
            label.text = "NO SE PUDO CREAR EAGLContext (OpenGL ES 2.0)"
            label.textColor = .systemOrange
            label.textAlignment = .center
            label.numberOfLines = 0
            onContextValidated(false)
            onGL3Initialized(-90)
            onGeometryDrawn(-90)
            return label
        }
        let view = GLKView(frame: .zero, context: glContext)
        view.delegate = context.coordinator
        view.drawableColorFormat = .RGBA8888
        view.drawableDepthFormat = .format16
        view.isOpaque = true
        view.enableSetNeedsDisplay = true
        view.setNeedsDisplay()
        return view
        #endif
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        (uiView as? GLKView)?.setNeedsDisplay()
    }

    final class Renderer: NSObject, GLKViewDelegate {
        let glContext: EAGLContext?
        private var textureID: GLuint = 0
        private let effect = GLKBaseEffect()
        var onContextValidated: ((Bool) -> Void)?
        var onGL3Initialized: ((Int32) -> Void)?
        var onGeometryDrawn: ((Int32) -> Void)?
        private var didValidateNativeContext = false
        private var didRunGeometryTest = false

        override init() {
            glContext = EAGLContext(api: .openGLES2)
            super.init()
            guard let glContext, EAGLContext.setCurrent(glContext) else { return }
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
            guard let glContext, EAGLContext.setCurrent(glContext) else { return }
            if !didValidateNativeContext {
                didValidateNativeContext = true
                onContextValidated?(krosaOpenGLESContextSmokeTest() == 1)
            }

            // Avoid GLKView drawable size getters: their GLES dispatch crashes on this simulator.
            let drawableWidth = max(1, Int32(view.bounds.width * view.contentScaleFactor))
            let drawableHeight = max(1, Int32(view.bounds.height * view.contentScaleFactor))
            glViewport(0, 0, drawableWidth, drawableHeight)
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
                    drawableWidth, drawableHeight
                )
                onGL3Initialized?(krosaGetLastGeometryInitStatus())
                onGeometryDrawn?(result)
            }
        }

        deinit {
            if textureID != 0 {
                if let glContext {
                    _ = EAGLContext.setCurrent(glContext)
                    glDeleteTextures(1, &textureID)
                }
            }
        }
    }
}
