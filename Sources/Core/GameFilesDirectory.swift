import Foundation

/// The app's Documents directory is exposed in Files as "KroSA".
/// Place the San Andreas data folders directly inside it (anim, audio, data,
/// models, texdb, etc.). The engine must receive this absolute path as its
/// game-files/Documents root; do not use the app bundle or a hard-coded path.
enum GameFilesDirectory {
    static func prepare() throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        return documents
    }

    static var url: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var path: String {
        url.path
    }
}
