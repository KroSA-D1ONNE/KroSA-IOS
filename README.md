# KroSA iOS

KroSA is an iOS-native project to build a Grand Theft Auto: San Andreas multiplayer client compatible with SA-MP/Open.MP servers.

## Current status

This repository is a clean project bootstrap. It contains the iOS app shell and a reproducible unsigned build workflow. **The GTA: San Andreas engine and multiplayer runtime are not integrated yet.** The app must not be considered a playable client until those components are connected and tested on a device.

## Technical direction

- **Platform:** iOS, initially iPhone.
- **UI / app lifecycle:** SwiftUI.
- **Game engine:** integrate the authorized ReSA/RenderWare-based iOS engine rather than introducing Unity.
- **Graphics path:** preserve the engine's native rendering path (OpenGL ES / SDL2, subject to binary and iOS compatibility validation).
- **Multiplayer:** implement and validate the SA-MP 0.3.7 protocol path, including RakNet transport, RPCs, connection handshake, and player synchronization.
- **Architecture:** keep the launcher, engine adapter, networking layer, and game runtime separated.

## Repository layout

```
KroSA-iOS/
├── Sources/
│   ├── App/
│   │   ├── KroSAApp.swift
│   │   └── ContentView.swift
│   ├── Core/
│   │   └── GameLaunchConfiguration.swift
│   └── Engine/
│       └── GameEngineBridge.swift
├── Resources/
├── .github/workflows/
│   └── ios-build.yml
└── project.yml
```

## Build

Requirements:
- macOS with Xcode
- XcodeGen

Generate and build:

```sh
xcodegen generate
xcodebuild -project KroSA.xcodeproj -scheme KroSA -sdk iphoneos -configuration Release CODE_SIGNING_ALLOWED=NO
```

GitHub Actions runs the same unsigned iOS build on pushes and pull requests. The resulting artifact is for build validation only; installing on a physical iPhone requires signing with a valid development/distribution certificate.

## Important integration constraints

The ReSA engine and loader are currently treated as external binary dependencies. Before adding them, verify:
1. framework architectures and minimum iOS deployment target;
2. public headers / exported symbols and required linker flags;
3. embedded frameworks, dynamic-library load paths, and code-signing requirements;
4. SDL2 / OpenGL ES compatibility on the target iOS versions;
5. ownership and permission for every binary and asset included in this repository.

Do not commit proprietary GTA assets or binaries unless redistribution rights explicitly allow it.
