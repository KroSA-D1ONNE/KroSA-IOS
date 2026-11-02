# ReSA 1.1.2 binary inspection

This note records observations from the user-provided `resa-ios-1.1.2` IPA. It is not a claim that ReSA has been integrated into KroSA.

## Confirmed from the IPA

- App executable: `Payload/ReSALauncher.app/ReSALauncher` (Mach-O arm64).
- `ReSAEngine.framework`: bundle ID `com.alyn.resa.engine`, minimum iOS 15.1, arm64.
- `alloader.framework`: bundle ID `com.alyn.resa.alloader`, minimum iOS 15.1, arm64.
- The app links `@rpath/ReSAEngine.framework/ReSAEngine`.
- The app executable contains the Swift lifecycle type `ReSAEngineLifecycle`, plus `SADataBootstrap` and `IOSLauncherBridge`.
- The app executable references these native bridge symbols:
  - `ReSAIOSConfigureDocumentsRoot`
  - `ReSAIOSCopyDocumentsRoot`
  - `ReSAIOSHostStart`
  - `ReSAIOSHostRequestStop`
  - `ReSAIOSHostCopyStatus`
  - `ReSAIOSHostRunGeneration`
  - `ReSAIOSBootstrapReady`
  - `ReSAIOSEngineAvailable`
  - `ReSAIOSBootstrapStatus`
- The app contains diagnostics including `documents-root-not-configured`, `documents-root-rejected`, and `launcher: handoff readiness rejected by Documents/TEXT bootstrap`.

## Consequence for KroSA

The startup contract is not just a call to a generic engine initializer. The original launcher performs a documents-root validation/bootstrap and then coordinates an engine lifecycle and host handoff. The wrapper symbols above are observed in the **ReSALauncher app executable**; their presence in that executable does not make them automatically callable from a new KroSA target.

KroSA currently prepares its own app Documents directory and exposes that absolute path as the intended game-data root. The next integration step is to establish the exact ABI/signatures and ownership of the bridge functions, then port/reimplement the lifecycle/bootstrap in KroSA. Do not guess C function signatures or call undocumented symbols based only on strings.

## Data layout

The iOS Documents directory is the app-private directory exposed in Files as `On My iPhone/KroSA`. GTA data folders supplied by the user should be placed directly beneath it (for example `anim/`, `audio/`, `data/`, `models/`, and `texdb/`). KroSA must validate required folders before handing the path to the engine.

## Not yet verified

- Full transitive dynamic-library dependencies and linker flags.
- Public headers and exact C ABI declarations for the bridge.
- Whether the two frameworks can be embedded and loaded independently of the original Flutter launcher.
- Whether the supplied game-data set matches the exact ReSA engine build.
- Successful engine startup on a physical iPhone.

The unsigned CI build validates only the Swift launcher target. It is not a playable build.


## Additional ABI inspection (2026-11-02)

The two framework Mach-O binaries are arm64 dynamic libraries and both declare iOS 15.1 as their minimum OS. The ReSAEngine framework's direct dynamic dependencies include CoreVideo, CoreAudio, AudioToolbox, AVFoundation/AVFAudio, CoreBluetooth, CoreGraphics, CoreMotion, Foundation/CoreFoundation, GameController (weak), Metal, OpenGLES, QuartzCore, UIKit, CoreHaptics (weak), OpenAL, IOSurface, Security, WebKit, zlib, and libc++.

The ReSAEngine binary exports the following C symbols (leading underscore is the Mach-O symbol convention):

- `ReSAIOSConfigureDocumentsRoot`
- `ReSAIOSBootstrapReady`
- `ReSAIOSEngineAvailable`
- `ReSAIOSBootstrapStatus`
- `ReSAIOSCopyDocumentsRoot`
- `ReSAIOSHostCopyStatus`
- `ReSAIOSHostCanStart`
- `ReSAIOSHostStart`
- `ReSAIOSHostRequestStop`
- `ReSAIOSHostRunGeneration`
- `ReSAIOSHostStateToken`
- `ReSAIOSEngineGetApi`

Important finding: the disassembly of `ReSAIOSEngineAvailable` at framework offset `0x86c8` is just `mov w0, #0; ret`. In this supplied framework binary the function therefore returns false unconditionally. That is a concrete blocker: the framework alone cannot currently be treated as a ready-to-launch engine. The original launcher may have additional bootstrap/registration steps or this framework may be a deliberately unavailable build. We must inspect the original app's call sequence and the versioned engine API before attempting to call `HostStart`.

The `ReSAIOSHostStart` entry validates a caller-provided structure whose first 32-bit field must be at least `0x50` bytes and whose pointer fields at offsets `0x08` and `0x10` must be non-null. This is not enough to define the structure safely; do not construct it in Swift until its complete layout and ownership are recovered from the launcher executable/API metadata.

