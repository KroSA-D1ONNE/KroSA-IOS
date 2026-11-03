import SwiftUI
import GLKit
import OpenGLES

/// Native GLES2 texture test. Uses an EAGLContext, a real GL texture,
/// UV coordinates and GLKBaseEffect's GLES shader pipeline.
struct GPUTestView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var nativeGLStatus = "EAGL + GLES2 SHADER AISLADO"
    @State private var librwGL3Status = "LIBRW GL3: NO EJECUTADO"
    @State private var geometryStatus = "TRIÁNGULO GLES2: EN PRUEBA"
    @State private var diagnosticsStatus = "MÉTRICAS LIBRW: ESPERANDO FRAME"
    @State private var showLibrwTest = false

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.045, blue: 0.04).ignoresSafeArea()
            VStack(spacing: 16) {
                HStack {
                    Text("KroSA")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                    Spacer()
                    Text("RENDERWARE · EAGL")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                }
                .foregroundStyle(.white)

                Text("PRUEBA GRÁFICA")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))

                if showLibrwTest {
                    GLES2TextureView(
                        onContextValidated: { ok in nativeGLStatus = ok ? "EAGL CONTEXTO: OK" : "EAGL CONTEXTO: ERROR" },
                        onGL3Initialized: { status in librwGL3Status = "LIBRW GL3 INIT: \(status)" },
                        onGeometryDrawn: { result in geometryStatus = "LIBRW DRAW: \(result)" },
                        onDiagnostics: { diagnosticsStatus = $0 }
                    )
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.35), lineWidth: 1))
                    Text("LIBRW GL3 + TRIÁNGULO GLES2 DE CONTROL")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                } else {
                    Spacer(minLength: 24)
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 72, weight: .ultraLight))
                        .foregroundStyle(.green)
                    Text("Motor gráfico nativo")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("RenderWare · librw GL3 · OpenGL ES")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer(minLength: 24)
                }

                VStack(alignment: .leading, spacing: 7) {
                    statusLine(nativeGLStatus)
                    statusLine(librwGL3Status)
                    statusLine(geometryStatus)
                    Text(diagnosticsStatus)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(13)
                .background(Color.white.opacity(0.055))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Button {
                    showLibrwTest.toggle()
                } label: {
                    Text(showLibrwTest ? "DETENER PRUEBA GLES2" : "PROBAR SHADERS GLES2")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                }

                Button("VOLVER") { dismiss() }
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.vertical, 8)
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
    }

    private func statusLine(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(value.contains("OK") ? .green : .orange)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
    }
}

/// GLKView can receive its first draw request while SwiftUI is still assigning
/// its final frame. Retry once the drawable has a real, non-zero layout size.
private final class KroSAGLKView: GLKView {
    private var lastDrawableBounds: CGRect = .zero

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }
        guard bounds != lastDrawableBounds else { return }
        lastDrawableBounds = bounds
        setNeedsDisplay()
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
        let view = KroSAGLKView(frame: .zero, context: glContext)
        view.delegate = context.coordinator
        view.drawableColorFormat = .RGBA8888
        view.drawableDepthFormat = .format16
        view.isOpaque = true
        view.enableSetNeedsDisplay = true
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Renderer.handlePan(_:)))
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Renderer.handlePinch(_:)))
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)
        context.coordinator.hostView = view
        // Wait until SwiftUI has completed its first layout before requesting
        // the initial frame; layoutSubviews also retries if the size changes.
        DispatchQueue.main.async { [weak view] in
            guard let view, view.bounds.width > 0, view.bounds.height > 0 else { return }
            view.setNeedsDisplay()
        }
        return view
        #endif
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Renderer) {
        #if !targetEnvironment(simulator)
        if let glContext = coordinator.glContext {
            _ = EAGLContext.setCurrent(glContext)
            krosaLibrwGL3Shutdown()
            EAGLContext.setCurrent(nil)
        }
        #endif
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Do not redraw merely because SwiftUI refreshed status labels.
        // The first frame is requested by makeUIView/layoutSubviews; camera
        // gestures explicitly request their own frames. Re-entering librw
        // from a status-only SwiftUI update recreated native GPU resources.
    }


    final class Renderer: NSObject, GLKViewDelegate {
        let glContext: EAGLContext?
        private var textureID: GLuint = 0
        private let effect = GLKBaseEffect()
        private var sentinelProgram: GLuint = 0
        var onContextValidated: ((Bool) -> Void)?
        var onGL3Initialized: ((Int32) -> Void)?
        var onGeometryDrawn: ((Int32) -> Void)?
        private var didValidateNativeContext = false
        private var didRunGeometryTest = false
        private var lastReportedGeometryResult: Int32?
        weak var hostView: GLKView?
        private var cameraYaw: Float = 0.62
        private var cameraPitch: Float = 0.38
        private var cameraDistance: Float = 3.2
        private var lastPanPoint = CGPoint.zero
        private var pinchStartDistance: Float = 3.2

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

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let point = gesture.translation(in: gesture.view)
            if gesture.state == .began { lastPanPoint = point; return }
            let dx = Float(point.x - lastPanPoint.x)
            let dy = Float(point.y - lastPanPoint.y)
            lastPanPoint = point
            cameraYaw += dx * 0.008
            cameraPitch = min(1.35, max(-1.35, cameraPitch + dy * 0.008))
            hostView?.setNeedsDisplay()
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            if gesture.state == .began { pinchStartDistance = cameraDistance }
            cameraDistance = min(7.0, max(1.8, pinchStartDistance / Float(gesture.scale)))
            hostView?.setNeedsDisplay()
        }

        private func buildSentinelProgram() -> GLuint {
            let vertexSource = "attribute vec2 aPosition; void main(){ gl_Position = vec4(aPosition, 0.0, 1.0); }"
            let fragmentSource = "precision mediump float; void main(){ gl_FragColor = vec4(1.0, 0.82, 0.12, 1.0); }"
            func compile(_ type: GLenum, _ source: String) -> GLuint {
                let shader = glCreateShader(type)
                guard shader != 0 else { return 0 }
                source.withCString { pointer in
                    var sourcePointer: UnsafePointer<GLchar>? = UnsafeRawPointer(pointer).assumingMemoryBound(to: GLchar.self)
                    glShaderSource(shader, 1, &sourcePointer, nil)
                }
                glCompileShader(shader)
                var status: GLint = 0
                glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &status)
                if status != GL_TRUE { glDeleteShader(shader); return 0 }
                return shader
            }
            let vertex = compile(GLenum(GL_VERTEX_SHADER), vertexSource)
            let fragment = compile(GLenum(GL_FRAGMENT_SHADER), fragmentSource)
            guard vertex != 0, fragment != 0 else {
                if vertex != 0 { glDeleteShader(vertex) }
                if fragment != 0 { glDeleteShader(fragment) }
                return 0
            }
            let linked = glCreateProgram()
            glAttachShader(linked, vertex)
            glAttachShader(linked, fragment)
            glBindAttribLocation(linked, 0, "aPosition")
            glLinkProgram(linked)
            glDeleteShader(vertex)
            glDeleteShader(fragment)
            var status: GLint = 0
            glGetProgramiv(linked, GLenum(GL_LINK_STATUS), &status)
            if status != GL_TRUE { glDeleteProgram(linked); return 0 }
            return linked
        }

        private func drawSentinelTriangle(width: Int32, height: Int32) {
            if sentinelProgram == 0 { sentinelProgram = buildSentinelProgram() }
            guard sentinelProgram != 0 else { return }
            let vertices: [GLfloat] = [0.0, 0.72, -0.68, -0.58, 0.68, -0.58]
            glViewport(0, 0, width, height)
            glDisable(GLenum(GL_DEPTH_TEST))
            glDisable(GLenum(GL_CULL_FACE))
            glDisable(GLenum(GL_SCISSOR_TEST))
            glDisable(GLenum(GL_BLEND))
            glUseProgram(sentinelProgram)
            // librw leaves its own VBO bound. With a non-zero ARRAY_BUFFER,
            // glVertexAttribPointer interprets the Swift pointer as a byte offset,
            // which can make Apple's GL driver abort when the frame is flushed.
            glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
            glEnableVertexAttribArray(0)
            vertices.withUnsafeBufferPointer { buffer in
                guard let base = buffer.baseAddress else { return }
                glVertexAttribPointer(0, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 0, UnsafeRawPointer(base))
                glDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
            }
            glDisableVertexAttribArray(0)
            glUseProgram(0)
            // GLKView owns presentation/flush for this drawable.
        }

        func glkView(_ view: GLKView, drawIn rect: CGRect) {
            guard let glContext, EAGLContext.setCurrent(glContext) else { return }
            // SwiftUI may invoke the delegate before the first non-zero layout.
            // Do not initialize librw against a zero-sized host drawable.
            guard view.bounds.width > 0, view.bounds.height > 0 else { return }

            if !didValidateNativeContext {
                didValidateNativeContext = true
                let contextIsValid = krosaOpenGLESContextSmokeTest() == 1
                DispatchQueue.main.async { [weak self] in
                    self?.onContextValidated?(contextIsValid)
                }
            }

            // Avoid GLKView drawable size getters: their GLES dispatch crashes on this simulator.
            let drawableWidth = Int32(view.bounds.width * view.contentScaleFactor)
            let drawableHeight = Int32(view.bounds.height * view.contentScaleFactor)
            guard drawableWidth > 0, drawableHeight > 0 else { return }
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

            // Re-render librw with the current touch-controlled camera.
            // RenderWare's device and GL3 shaders remain alive between frames.
            let result = krosaLibrwGL3GeometrySmokeTest(
                drawableWidth, drawableHeight, cameraYaw, cameraPitch, cameraDistance
            )
            if !didRunGeometryTest {
                didRunGeometryTest = true
                let initStatus = krosaGetLastGeometryInitStatus()
                DispatchQueue.main.async { [weak self] in
                    self?.onGL3Initialized?(initStatus)
                }
            }

            // Report only changes, not every frame: this exposes a transient
            // librw failure without causing SwiftUI state-update/render recursion.
            if lastReportedGeometryResult != result {
                lastReportedGeometryResult = result
                DispatchQueue.main.async { [weak self] in
                    self?.onGeometryDrawn?(result)
                }
            }

            // Draw a known-good GLES2 marker AFTER librw. If this yellow triangle
            // survives, GLKView's drawable/presentation path is still usable and
            // the remaining fault is inside librw's geometry submission/output.
            drawSentinelTriangle(width: drawableWidth, height: drawableHeight)
        }

        deinit {
            if sentinelProgram != 0 {
                if let glContext { _ = EAGLContext.setCurrent(glContext) }
                glDeleteProgram(sentinelProgram)
            }
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
