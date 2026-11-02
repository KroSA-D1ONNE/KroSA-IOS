import Foundation

struct GameLaunchConfiguration: Equatable {
    let nickname: String
    let host: String
    let port: UInt16
    /// Absolute app-container path. The ReSA adapter must configure the engine
    /// with this path before engine startup.
    let gameFilesPath: String

    init?(nickname: String, host: String, port: String) {
        let cleanNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanNickname.isEmpty,
              !cleanHost.isEmpty,
              let parsedPort = UInt16(port),
              parsedPort > 0 else {
            return nil
        }

        self.nickname = cleanNickname
        self.host = cleanHost
        self.port = parsedPort
        self.gameFilesPath = GameFilesDirectory.path
    }
}
