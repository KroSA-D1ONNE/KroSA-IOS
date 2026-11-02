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
