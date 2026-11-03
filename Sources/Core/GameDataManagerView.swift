import SwiftUI
import UniformTypeIdentifiers

/// Imports a user-owned GTA SA data directory into Documents/KroSA.
/// Existing files are preserved; matching directories are merged recursively.
struct GameDataManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var report = GameDataBootstrap.inspect()
    @State private var showingFolderPicker = false
    @State private var isImporting = false
    @State private var message = "Seleccioná la carpeta raíz de GTA San Andreas."
    @State private var importedFiles = 0

    private let requiredFolders = ["anim", "audio", "data", "models", "texdb"]

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.035, green: 0.045, blue: 0.04).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("DATOS DEL JUEGO")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(.green)
                            Text("KroSA revisa los recursos disponibles y utiliza los archivos desde el almacenamiento de la app.")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.65))
                        }

                        Button { showingFolderPicker = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "folder.badge.plus").font(.system(size: 22))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(isImporting ? "IMPORTANDO…" : "IMPORTAR CARPETA DEL JUEGO")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    Text("Elegí la carpeta principal de GTA San Andreas")
                                        .font(.system(size: 10)).opacity(0.7)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundStyle(.black)
                            .padding(16)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                        }
                        .disabled(isImporting)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("ESTADO DE LOS RECURSOS")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                            folderRow("anim")
                            folderRow("audio")
                            folderRow("data")
                            folderRow("models")
                            folderRow("texdb")
                            folderRow("TEXT/american.gxt")
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.055))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        Text(message)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(13)
                            .background(Color.white.opacity(0.045))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        Text("Los archivos existentes no se sobrescriben. La importación copia la carpeta elegida a Documents/KroSA; no agrega la data a la IPA ni al repositorio.")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
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
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false,
            onCompletion: handleFolderSelection
        )
        .onAppear(perform: refresh)
    }

    @ViewBuilder
    private func folderRow(_ name: String) -> some View {
        let exists = hasResource(name)
        HStack {
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

    private func hasResource(_ name: String) -> Bool {
        let url = GameFilesDirectory.url.appendingPathComponent(name)
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        if name == "TEXT/american.gxt" { return exists && !isDirectory.boolValue }
        return exists && isDirectory.boolValue
    }

    private func refresh() {
        try? GameFilesDirectory.prepare()
        report = GameDataBootstrap.inspect()
    }

    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            message = "No se pudo seleccionar la carpeta: \(error.localizedDescription)"
        case .success(let urls):
            guard let source = urls.first else { return }
            isImporting = true
            message = "Copiando recursos…"
            DispatchQueue.global(qos: .userInitiated).async {
                let accessed = source.startAccessingSecurityScopedResource()
                defer { if accessed { source.stopAccessingSecurityScopedResource() } }
                do {
                    let destination = try GameFilesDirectory.prepare()
                    let count = try Self.mergeDirectoryContents(from: source, to: destination)
                    DispatchQueue.main.async {
                        importedFiles = count
                        isImporting = false
                        refresh()
                        message = "Importación terminada: \(count) archivos nuevos. \(report.summary)"
                    }
                } catch {
                    DispatchQueue.main.async {
                        isImporting = false
                        message = "Error al importar: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    /// Merges a selected game root into Documents without replacing user files.
    private static func mergeDirectoryContents(from source: URL, to destination: URL) throws -> Int {
        let manager = FileManager.default
        let children = try manager.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        var copied = 0
        for child in children {
            let target = destination.appendingPathComponent(child.lastPathComponent)
            let values = try child.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if values.isDirectory == true {
                if manager.fileExists(atPath: target.path) {
                    var targetIsDirectory: ObjCBool = false
                    guard manager.fileExists(atPath: target.path, isDirectory: &targetIsDirectory),
                          targetIsDirectory.boolValue else { continue }
                    copied += try mergeDirectoryContents(from: child, to: target)
                } else {
                    try manager.copyItem(at: child, to: target)
                    copied += countFiles(in: child)
                }
            } else if values.isRegularFile == true && !manager.fileExists(atPath: target.path) {
                try manager.copyItem(at: child, to: target)
                copied += 1
            }
        }
        return copied
    }

    private static func countFiles(in directory: URL) -> Int {
        guard let enumerator = FileManager.default.enumerator(
            at: directory, includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        return enumerator.reduce(into: 0) { count, item in
            guard let url = item as? URL,
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { return }
            count += 1
        }
    }
}
