import Foundation

struct GameLaunchConfiguration: Equatable {
    let nickname: String
    let host: String
    let port: UInt16

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
    }
}
