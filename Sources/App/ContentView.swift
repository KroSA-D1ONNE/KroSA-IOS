import SwiftUI

struct ContentView: View {
    @State private var nickname = ""
    @State private var serverAddress = ""
    @State private var serverPort = "7777"

    private var canContinue: Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !serverAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        UInt16(serverPort) != nil
    }

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.045, blue: 0.04).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 10) {
                    Text("KroSA")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(Color(red: 0.35, green: 0.95, blue: 0.48))

                    Text("SAN ANDREAS MULTIPLAYER")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer().frame(height: 54)

                VStack(alignment: .leading, spacing: 18) {
                    inputField(title: "NICKNAME", placeholder: "Tu nombre", text: $nickname)
                    inputField(title: "SERVER IP / HOST", placeholder: "127.0.0.1", text: $serverAddress)
                    inputField(title: "PORT", placeholder: "7777", text: $serverPort)
                        .keyboardType(.numberPad)
                }

                Spacer().frame(height: 28)

                Button(action: {}) {
                    HStack(spacing: 10) {
                        Text("INICIAR JUEGO")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.black.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(canContinue ? Color(red: 0.35, green: 0.95, blue: 0.48) : Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(true)

                Text("GAME ENGINE NOT CONNECTED")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.top, 16)

                Spacer()
                Text("KroSA · iOS")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.25))
                    .padding(.bottom, 18)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: 460)
        }
    }

    private func inputField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.5))

            TextField(placeholder, text: text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 15)
                .padding(.vertical, 15)
                .background(Color.white.opacity(0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
