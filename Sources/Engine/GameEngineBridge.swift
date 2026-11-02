import Foundation

/// Boundary between the native KroSA launcher and the embedded game runtime.
///
/// The actual ReSA engine adapter belongs behind this interface. Keep binary-specific
/// calls out of SwiftUI so the UI can be built and tested independently.
protocol GameEngineBridge {
    var isAvailable: Bool { get }
    func launch(configuration: GameLaunchConfiguration) throws
}

enum GameEngineError: LocalizedError {
    case engineNotIntegrated
    case engineUnavailable

    var errorDescription: String? {
        switch self {
        case .engineNotIntegrated:
            return "The game engine has not been integrated into this build."
        case .engineUnavailable:
            return "The game engine could not be loaded."
        }
    }
}

/// Safe placeholder until the authorized engine framework is added and validated.
struct UnavailableGameEngineBridge: GameEngineBridge {
    let isAvailable = false

    func launch(configuration: GameLaunchConfiguration) throws {
        throw GameEngineError.engineNotIntegrated
    }
}
