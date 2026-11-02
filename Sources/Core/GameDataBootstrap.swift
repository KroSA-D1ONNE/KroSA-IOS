import Foundation

struct GameDataReport: Equatable {
    let missingDirectories: [String]
    let hasAmericanText: Bool

    var isReady: Bool {
        missingDirectories.isEmpty && hasAmericanText
    }

    var summary: String {
        if !missingDirectories.isEmpty {
            return "FALTAN: " + missingDirectories.joined(separator: ", ")
        }
        if !hasAmericanText {
            return "FALTA TEXT/american.gxt"
        }
        return "ARCHIVOS DEL JUEGO DETECTADOS"
    }
}

/// Checks the user-provided GTA San Andreas installation in this app's
/// Documents directory. It deliberately does not download or fabricate assets.
enum GameDataBootstrap {
    private static let requiredDirectories = ["anim", "audio", "data", "models", "texdb"]

    static func inspect(documentsRoot: URL = GameFilesDirectory.url) -> GameDataReport {
        let manager = FileManager.default
        let missing = requiredDirectories.filter { name in
            var isDirectory: ObjCBool = false
            let url = documentsRoot.appendingPathComponent(name, isDirectory: true)
            return !manager.fileExists(atPath: url.path, isDirectory: &isDirectory) || !isDirectory.boolValue
        }

        let textFile = documentsRoot.appendingPathComponent("TEXT/american.gxt")
        let hasText = manager.fileExists(atPath: textFile.path)
        return GameDataReport(missingDirectories: missing, hasAmericanText: hasText)
    }

    /// Copies bundled GXT resources into Documents/TEXT without overwriting
    /// user files. The original ReSA launcher provisions these resources too.
    static func provisionBundledText(
        bundle: Bundle = .main,
        documentsRoot: URL = GameFilesDirectory.url
    ) throws {
        let manager = FileManager.default
        guard let source = bundle.resourceURL?.appendingPathComponent("TEXT", isDirectory: true) else {
            return
        }

        var isDirectory: ObjCBool = false
        guard manager.fileExists(atPath: source.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return
        }

        let destination = documentsRoot.appendingPathComponent("TEXT", isDirectory: true)
        try manager.createDirectory(at: destination, withIntermediateDirectories: true)

        let files = try manager.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        for file in files where file.pathExtension.lowercased() == "gxt" {
            let values = try file.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            let target = destination.appendingPathComponent(file.lastPathComponent)
            guard !manager.fileExists(atPath: target.path) else { continue }
            try manager.copyItem(at: file, to: target)
        }
    }
}
