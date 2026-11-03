import Foundation

/// The app's Documents directory is exposed in Files as "KroSA".
/// Keep a small user-visible guide in the root so iOS Files has content
/// to index and does not hide the app's otherwise-empty Documents location.
enum GameFilesDirectory {
    private static let welcomeFileName = "LEEME - KroSA.txt"

    static func prepare() throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let manager = FileManager.default
        try manager.createDirectory(at: documents, withIntermediateDirectories: true)

        let welcomeFile = documents.appendingPathComponent(welcomeFileName)
        if !manager.fileExists(atPath: welcomeFile.path) {
            let instructions = """
            KroSA - Archivos del juego

            Copiá acá los archivos y carpetas de GTA San Andreas.
            Por ejemplo: anim, audio, data, models, texdb y TEXT.

            Esta carpeta aparece en Archivos > En mi iPhone > KroSA.
            No borres este archivo si todavía no agregaste los archivos del juego.
            """
            try instructions.write(to: welcomeFile, atomically: true, encoding: .utf8)
        }

        return documents
    }

    static var url: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var path: String {
        url.path
    }
}
