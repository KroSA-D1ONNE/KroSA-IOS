import SwiftUI

/// Explains and inspects the app-owned Documents folder exposed in Files.
struct GameDataManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var report = GameDataBootstrap.inspect()

    private let resources = [
        ("anim", true),
        ("audio", true),
        ("data", true),
        ("models", true),
        ("texdb", true),
        ("TEXT/american.gxt", false)
    ]

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.035, green: 0.045, blue: 0.04).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("CARPETA DE KROSA")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(.green)
                            Text("La carpeta de esta app aparece automáticamente en Archivos, dentro de «En mi iPhone». No tenés que importar nada desde KroSA.")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.72))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Archivos", systemImage: "folder.fill")
                            Text("En mi iPhone  ›  KroSA")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.green)
                            Text("Copiá acá las carpetas y archivos del GTA San Andreas. Las carpetas del juego deben quedar directamente dentro de KroSA.")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        .padding(15)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.055))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 11) {
                            Text("ESTRUCTURA ESPERADA")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                            ForEach(resources, id: \.0) { item in
                                resourceRow(item.0, isDirectory: item.1)
                            }
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.055))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 6) {
                            Text(report.summary)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(report.isReady ? Color.green : Color.orange)
                            Text(report.isReady
                                 ? "Se detectaron las carpetas principales. Esto confirma su presencia, no todavía que todos los archivos sean válidos."
                                 : "Todavía faltan recursos. Cuando termines de copiarlos, tocá «Volver a revisar».")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.58))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(13)
                        .background(Color.white.opacity(0.045))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        Button(action: refresh) {
                            Label("VOLVER A REVISAR", systemImage: "arrow.clockwise")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .background(Color.green)
                                .clipShape(RoundedRectangle(cornerRadius: 11))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Listo") { dismiss() }.foregroundStyle(.green)
                }
            }
            .preferredColorScheme(.dark)
        }
        .onAppear(perform: refresh)
    }

    @ViewBuilder
    private func resourceRow(_ name: String, isDirectory: Bool) -> some View {
        let exists = hasResource(name, isDirectory: isDirectory)
        HStack(spacing: 9) {
            Image(systemName: exists ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(exists ? Color.green : Color.orange)
            Text(name)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            Text(exists ? "DETECTADO" : "FALTA")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(exists ? Color.green : Color.orange)
        }
    }

    private func hasResource(_ name: String, isDirectory: Bool) -> Bool {
        let url = GameFilesDirectory.url.appendingPathComponent(name)
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        return exists && (isDirectory ? isDir.boolValue : !isDir.boolValue)
    }

    private func refresh() {
        try? GameFilesDirectory.prepare()
        report = GameDataBootstrap.inspect()
    }
}
