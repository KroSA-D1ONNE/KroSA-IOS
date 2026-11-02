import SwiftUI

struct ContentView: View {
    @State private var nickname = ""
    @State private var serverAddress = ""
    @State private var serverPort = "7777"
    @State private var dataReport = GameDataBootstrap.inspect()

    private var canContinue: Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !serverAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        UInt16(serverPort) != nil && dataReport.isReady
    }

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.045, blue: 0.04).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 10) {
                    Text("KroSA")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.35, green: 0.95, blue: 0.48))

                    Text("SAN ANDREAS MULTIPLAYER")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer().frame(height: 54)

                VStack(alignment: .leading, spacing: 18) {
                    inputField(title: "NICKNAME", placeholder: "Tu nombre", text: $nickname)
                    inputField(title: "SERVER IP / HOST", placeholder: "127.0.0.1", text: $serverAddress)
                    inputField(title: "PORT", placeholder: "7777", text: $serverPort)
                        .keyboardType(.numberPad)
                }

                Spacer().frame(height: 24)

                HStack(spacing: 9) {
                    Image(systemName: dataReport.isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    Text(dataReport.summary)
                        .lineLimit(2)
                }
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(dataReport.isReady ? Color.green : Color.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(13)
                .background(Color.white.opacity(0.045))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Spacer().frame(height: 18)

                Button(action: {}) {
                    HStack(spacing: 10) {
                        Text("INICIAR JUEGO")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(canContinue ? Color(red: 0.35, green: 0.95, blue: 0.48) : Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(true)

                Text(dataReport.isReady ? "GAME ENGINE NOT INTEGRATED" : "COPIÁ LOS ARCHIVOS DE GTA SA EN DOCUMENTS/KROSA")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
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
        .onAppear(perform: refreshDataStatus)
    }

    private func refreshDataStatus() {
        try? GameDataBootstrap.provisionBundledText()
        dataReport = GameDataBootstrap.inspect()
    }

    private func inputField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
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
