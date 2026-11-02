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
    @State private var showGLKViewTest = false
    @State private var showTriangleTest = false
    @State private var showLibrwTest = false

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.045, blue: 0.04).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("KroSA · GRAPHICS TEST")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                VStack(spacing: 14) {
                    Image(systemName: "cpu")
                        .font(.system(size: 42, weight: .light))
                        .foregroundStyle(.green)
                    Text("DIAGNÓSTICO EAGL POR ETAPAS")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("Primero se comprueba únicamente la creación del contexto EAGL. Todavía no se crea GLKView ni se llama a librw.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                    Button("PROBAR CONTEXTO EAGL") {
                        let context = EAGLContext(api: .openGLES2)
                        guard let context, EAGLContext.setCurrent(context) else {
                            nativeGLStatus = "EAGL CONTEXT: ERROR · NO SE PUDO CREAR/ACTIVAR"
                            return
                        }
                        let version = glGetString(GLenum(GL_VERSION))
                        if version != nil {
                            nativeGLStatus = "EAGL CONTEXT: OK · OPENGL ES ACTIVO"
                        } else {
                            nativeGLStatus = "EAGL CONTEXT: ERROR · GL_VERSION NULO"
                        }
                        EAGLContext.setCurrent(nil)
                    }
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

                Button("INICIAR PRUEBA GLKVIEW") {
                    showGLKViewTest.toggle()
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if showGLKViewTest {
                    GLKClearTestView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 190)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Text("Si ves el panel verde, GLKView creó el framebuffer y ejecutó glClear.")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.green)
                        .multilineTextAlignment(.center)
                }

                Button("INICIAR PRUEBA TRIÁNGULO GLES2") {
                    showTriangleTest.toggle()
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if showTriangleTest {
                    GLESTriangleTestView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 190)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Text("Triángulo amarillo = compilación de shaders, enlace del programa y glDrawArrays GLES2.")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.green)
                        .multilineTextAlignment(.center)
                }

                Button("INICIAR LIBRW GL3 + GEOMETRÍA") {
                    showLibrwTest.toggle()
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if showLibrwTest {
                    GLES2TextureView(
                        onContextValidated: { valid in
                            nativeGLStatus = valid
                                ? "EAGL CONTEXT: OK · LIBRW PUEDE USAR EL CONTEXTO"
                                : "EAGL CONTEXT: ERROR · LIBRW"
                        },
                        onGL3Initialized: { result in
                            librwGL3Status = result == 1
                                ? "LIBRW GL3 / EAGL: OK · ENGINE + SHADERS"
                                : "LIBRW GL3 / EAGL: ERROR · ETAPA \(result)"
                        },
                        onGeometryDrawn: { result in
                            let flags = krosaGetLastGeometryDrawFlags()
                            let red = krosaGetLastGeometryPixel(0)
                            let green = krosaGetLastGeometryPixel(1)
                            let blue = krosaGetLastGeometryPixel(2)
                            let framebuffer = krosaGetLastGeometryFramebuffer()
                            let vx = krosaGetLastGeometryViewport(0)
                            let vy = krosaGetLastGeometryViewport(1)
                            let vw = krosaGetLastGeometryViewport(2)
                            let vh = krosaGetLastGeometryViewport(3)
                            let indices = krosaGetLastGeometryMetric(0)
                            let primitive = krosaGetLastGeometryMetric(1)
                            let vertices = krosaGetLastGeometryMetric(2)
                            let meshes = krosaGetLastGeometryMetric(3)
                            let attributes = krosaGetLastGeometryMetric(4)
                            let coloredPixels = krosaGetLastGeometryMetric(5)
                            let minX = krosaGetLastGeometryMetric(6)
                            let minY = krosaGetLastGeometryMetric(7)
                            let maxX = krosaGetLastGeometryMetric(8)
                            let maxY = krosaGetLastGeometryMetric(9)
                            let bluePixels = krosaGetLastGeometryMetric(10)
                            let nonBlackPixels = krosaGetLastGeometryMetric(11)
                            let maxGreen = krosaGetLastGeometryMetric(12)
                            let preBluePixels = krosaGetLastGeometryMetric(13)
                            geometryStatus = result == 1
                                ? "GEOMETRÍA LIBRW: OK · TRIÁNGULO DIBUJADO"
                                : "GEOMETRÍA LIBRW: ERROR \(result) · FLAGS \(flags) · PIX \(red),\(green),\(blue) · FBO \(framebuffer) · VP \(vx),\(vy),\(vw),\(vh) · IDX \(indices) · PRIM \(primitive) · VERT \(vertices) · MESH \(meshes) · ATTR \(attributes) · GREEN PX \(coloredPixels) · BOX \(minX),\(minY)-\(maxX),\(maxY) · BLUE PX \(bluePixels) · NONBLACK \(nonBlackPixels) · MAX G \(maxGreen) · PRE BLUE PX \(preBluePixels)"
                        }
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    Text("El fondo cuadriculado es GLKit; el triángulo verde debe dibujarlo el pipeline GL3 de librw.")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.green)
                        .multilineTextAlignment(.center)
                }

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
                    pixels[offset] = cell ? 30 : 15
                    pixels[offset + 1] = cell ? 60 : 25
                    pixels[offset + 2] = cell ? 220 : 90
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


/// Isolated physical-device test: GLKView creates its drawable and clears it.
/// It deliberately does not call librw, create shaders, or allocate textures.
private struct GLKClearTestView: UIViewRepresentable {
    func makeCoordinator() -> Renderer { Renderer() }

    func makeUIView(context: Context) -> GLKView {
        let glContext = EAGLContext(api: .openGLES2)!
        EAGLContext.setCurrent(glContext)
        let view = GLKView(frame: .zero, context: glContext)
        view.delegate = context.coordinator
        view.drawableColorFormat = .RGBA8888
        view.drawableDepthFormat = .formatNone
        view.enableSetNeedsDisplay = true
        view.isOpaque = true
        DispatchQueue.main.async { view.setNeedsDisplay() }
        return view
    }

    func updateUIView(_ uiView: GLKView, context: Context) {
        uiView.setNeedsDisplay()
    }

    final class Renderer: NSObject, GLKViewDelegate {
        func glkView(_ view: GLKView, drawIn rect: CGRect) {
            guard EAGLContext.setCurrent(view.context) else { return }
            let width = max(1, GLsizei(view.bounds.width * view.contentScaleFactor))
            let height = max(1, GLsizei(view.bounds.height * view.contentScaleFactor))
            glViewport(0, 0, width, height)
            glClearColor(0.04, 0.78, 0.22, 1.0)
            glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
            glFlush()
        }
    }
}


/// Isolated GLES2 shader + geometry test. No GLKit effects and no librw.
private struct GLESTriangleTestView: UIViewRepresentable {
    func makeCoordinator() -> Renderer { Renderer() }

    func makeUIView(context: Context) -> GLKView {
        let glContext = EAGLContext(api: .openGLES2)!
        EAGLContext.setCurrent(glContext)
        let view = GLKView(frame: .zero, context: glContext)
        view.delegate = context.coordinator
        view.drawableColorFormat = .RGBA8888
        view.drawableDepthFormat = .formatNone
        view.enableSetNeedsDisplay = true
        view.isOpaque = true
        DispatchQueue.main.async { view.setNeedsDisplay() }
        return view
    }

    func updateUIView(_ uiView: GLKView, context: Context) {
        uiView.setNeedsDisplay()
    }

    final class Renderer: NSObject, GLKViewDelegate {
        private var program: GLuint = 0
        private var shaderError: String?

        override init() {
            super.init()
        }

        private static func compile(_ type: GLenum, _ source: String) -> GLuint {
            let shader = glCreateShader(type)
            guard shader != 0 else { return 0 }
            source.withCString { pointer in
                var sourcePointer: UnsafePointer<GLchar>? = UnsafeRawPointer(pointer).assumingMemoryBound(to: GLchar.self)
                glShaderSource(shader, 1, &sourcePointer, nil)
            }
            glCompileShader(shader)
            var status: GLint = 0
            glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &status)
            guard status == GL_TRUE else {
                glDeleteShader(shader)
                return 0
            }
            return shader
        }

        private static func buildProgram() -> GLuint {
            let vertexSource = """
            attribute vec2 aPosition;
            void main() { gl_Position = vec4(aPosition, 0.0, 1.0); }
            """
            let fragmentSource = """
            precision mediump float;
            void main() { gl_FragColor = vec4(1.0, 0.82, 0.12, 1.0); }
            """
            let vertex = compile(GLenum(GL_VERTEX_SHADER), vertexSource)
            let fragment = compile(GLenum(GL_FRAGMENT_SHADER), fragmentSource)
            guard vertex != 0, fragment != 0 else {
                if vertex != 0 { glDeleteShader(vertex) }
                if fragment != 0 { glDeleteShader(fragment) }
                return 0
            }
            let linkedProgram = glCreateProgram()
            glAttachShader(linkedProgram, vertex)
            glAttachShader(linkedProgram, fragment)
            glBindAttribLocation(linkedProgram, 0, "aPosition")
            glLinkProgram(linkedProgram)
            glDeleteShader(vertex)
            glDeleteShader(fragment)
            var status: GLint = 0
            glGetProgramiv(linkedProgram, GLenum(GL_LINK_STATUS), &status)
            guard status == GL_TRUE else {
                glDeleteProgram(linkedProgram)
                return 0
            }
            return linkedProgram
        }

        func glkView(_ view: GLKView, drawIn rect: CGRect) {
            guard EAGLContext.setCurrent(view.context) else { return }
            let width = max(1, GLsizei(view.bounds.width * view.contentScaleFactor))
            let height = max(1, GLsizei(view.bounds.height * view.contentScaleFactor))
            glViewport(0, 0, width, height)
            glClearColor(0.035, 0.055, 0.10, 1.0)
            glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
            if program == 0 { program = Self.buildProgram() }
            guard program != 0 else { glFlush(); return }

            let vertices: [GLfloat] = [
                 0.0,  0.72,
                -0.68, -0.58,
                 0.68, -0.58
            ]
            glUseProgram(program)
            glEnableVertexAttribArray(0)
            vertices.withUnsafeBufferPointer { buffer in
                guard let base = buffer.baseAddress else { return }
                glVertexAttribPointer(0, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 0, UnsafeRawPointer(base))
                glDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
            }
            glDisableVertexAttribArray(0)
            glUseProgram(0)
            glFlush()
        }

        deinit {
            if program != 0 {
                _ = EAGLContext.setCurrent(EAGLContext.current())
                glDeleteProgram(program)
            }
        }
    }
}
