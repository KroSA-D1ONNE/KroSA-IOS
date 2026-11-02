import SwiftUI
import GLKit
import OpenGLES

/// Minimal OpenGL ES 2.0 renderer used to validate the native iOS GPU path.
/// This is deliberately isolated from the launcher and the future GTA runtime.
struct GPUTestView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.035, green: 0.045, blue: 0.04).ignoresSafeArea()

            VStack(spacing: 18) {
                Text("KroSA · GPU TEST")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                GLES2TriangleView()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.35), lineWidth: 1))

                Text("OpenGL ES 2.0 · EAGLContext")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.green)

                Text("Triángulo de prueba renderizado directamente en la GPU. Esto valida el contexto gráfico nativo; todavía no carga assets de GTA.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)

                Button("VOLVER") { dismiss() }
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 13)
                    .background(Color(red: 0.35, green: 0.95, blue: 0.48))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
    }
}

private struct GLES2TriangleView: UIViewRepresentable {
    func makeCoordinator() -> Renderer { Renderer() }

    func makeUIView(context: Context) -> GLKView {
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

        override init() {
            glContext = EAGLContext(api: .openGLES2)!
            super.init()
        }

        func glkView(_ view: GLKView, drawIn rect: CGRect) {
            guard EAGLContext.setCurrent(glContext) else { return }

            glClearColor(0.025, 0.04, 0.03, 1.0)
            glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))

            let effect = GLKBaseEffect()
            effect.useConstantColor = GLboolean(GL_TRUE)
            effect.constantColor = GLKVector4Make(0.30, 0.95, 0.45, 1.0)
            effect.transform.projectionMatrix = GLKMatrix4MakeOrtho(-1, 1, -1, 1, -1, 1)
            effect.transform.modelviewMatrix = GLKMatrix4Identity
            effect.prepareToDraw()

            let vertices: [GLfloat] = [
                 0.0,  0.72, 0.0,
                -0.68, -0.55, 0.0,
                 0.68, -0.55, 0.0
            ]

            vertices.withUnsafeBufferPointer { buffer in
                guard let baseAddress = buffer.baseAddress else { return }
                glEnableVertexAttribArray(GLuint(GLKVertexAttrib.position.rawValue))
                glVertexAttribPointer(
                    GLuint(GLKVertexAttrib.position.rawValue),
                    3,
                    GLenum(GL_FLOAT),
                    GLboolean(GL_FALSE),
                    0,
                    UnsafeRawPointer(baseAddress)
                )
                glDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
                glDisableVertexAttribArray(GLuint(GLKVertexAttrib.position.rawValue))
            }
        }
    }
}
