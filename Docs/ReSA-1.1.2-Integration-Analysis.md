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



## Original launcher call-site evidence

Further inspection of the original arm64 `ReSALauncher` executable confirms it directly imports the ReSAEngine C bridge symbols listed above. It also contains the concrete Swift types `IOSLauncherBridge`, `SADataBootstrap`, and `ReSAEngineLifecycle`. The mangled Swift symbol for the lifecycle entry point decodes to:

`start(documentsRoot:nickname:host:port:password:serverName:sessionToken:sessionTokenExpiresAt:)`

The launcher therefore owns important startup behavior that is not part of the two framework binaries alone. The executable also contains a `prepareAlLoader` method, so the alloader setup is an explicit launcher phase and should not be assumed to happen merely by embedding `alloader.framework`.

The strings `engine-not-linked`, `engine-not-ready`, and `bootstrap-ready-engine-not-linked` occur in the supplied app. Combined with the framework's unconditional-false `ReSAIOSEngineAvailable`, this strengthens the conclusion that the supplied binary set may intentionally lack a linked/available engine implementation, or requires a separate registration/linkage stage. We must resolve this before writing the KroSA adapter.

The next reverse-engineering target is the call sequence inside the original `ReSAEngineLifecycle.start`, plus `IOSLauncherBridge.configureEngineBootstrap` and `prepareAlLoader`. Recover the exact start-result structure and the host configuration struct layout before any FFI call. No guessed ABI has been added to KroSA.


## Follow-up inspection: bundled resources and loader

A full IPA directory listing shows that the original app bundle contains a top-level `TEXT/` resource directory with seven GXT language files: `american.gxt`, `french.gxt`, `german.gxt`, `italian.gxt`, `japanese.gxt`, `russian.gxt`, and `spanish.gxt`. The launcher contains an explicit `SADataBootstrap` class with a manifest of `RequiredFile` entries, source validation, temporary staging, SHA-256 calculation, and a `provision(documentsRoot:)` operation. Diagnostics explicitly mention that the Documents/TEXT bootstrap can reject the launch. This means the original launcher does not merely expect a GTA folder: it stages and validates bundled TEXT/GXT resources into the user Documents root before handoff.

The original launcher also has an explicit `prepareAlLoader() -> Bool` phase and an `alLoaderRootURL` property. The framework's `alloader` binary exports Lua 5.1-style APIs plus SA-MP event/packet hooks such as `_AL_OutgoingPacket`, `_AL_OutgoingRpc`, `_AL_IncomingPacket`, `_AL_IncomingRpc`, and `_AL_Connection`. Its framework bundle contains an `al_loader/lib/.al_lib_manifest` inventory of Lua modules, including `samp/events`, `samp/raknet`, and `samp/synchronization`. This is evidence that the alloader framework and its bundled Lua tree are a coupled runtime package; embedding only the Mach-O framework would be incomplete.

The supplied IPA also embeds `bass.framework` (audio runtime) and `objective_c.framework`, in addition to Flutter and app/ad frameworks. KroSA should not blindly copy every framework: first determine which are required by the native ReSA host path, then embed only those dependencies. The ReSAEngine binary directly links Apple audio, video, graphics, motion, Bluetooth, Metal/OpenGLES, UIKit, WebKit, Security, zlib, and libc++ frameworks. The alloader binary's direct dependencies are libc++ and libSystem.

### Confirmed integration implications

1. KroSA's Documents directory is a sensible user-visible root, but before engine handoff it must contain a valid `TEXT/` directory provisioned with the required GXT files and any manifest validation expected by the engine.
2. The original app's GXT source files live in its app bundle at `ReSALauncher.app/TEXT`; they are not in the two framework bundles. They have not been copied into the KroSA repository.
3. The alloader runtime needs its accompanying `al_loader/lib` tree and manifest. It is not sufficient to link `alloader.framework` alone.
4. The bridge and engine availability checks still need exact ABI recovery. Do not call `ReSAIOSHostStart` with a guessed structure, and do not assume the original app's Flutter lifecycle is required or can be transplanted wholesale.

This follow-up is based on static inspection of the user-provided IPA only. No engine launch, network connection, or physical-device test has been performed.


## Recovered launcher initialization sequence (2026-11-02)

The original arm64 launcher executable was disassembled at the Swift method call sites. This gives a concrete ordering for the setup phases:

1. `IOSLauncherBridge.configureEngineBootstrap(...)` resolves the install/root URL and invokes `SADataBootstrap.provision(documentsRoot:)`.
2. If provisioning throws, the launcher logs `ReSA iOS GXT bootstrap rejected launch: %@` and returns failure. The same method then obtains the Documents path and calls `ReSAIOSConfigureDocumentsRoot`; the path is passed as a UTF-8 C string (the disassembly shows a pointer plus a trailing NUL allocation).
3. `IOSLauncherBridge.prepareAlLoader()` obtains `alLoaderRootURL`, resolves the bundled source path `alloader.framework/al_loader/lib`, and reads the bundled `.al_lib_manifest`. The manifest is used to validate/copy the Lua runtime tree into its prepared destination; the method returns false on filesystem/manifest failure.
4. Only after these preparation phases does the launcher proceed toward its engine lifecycle/handoff. The bridge also contains a separate `validatedHandoffRoot` routine, so the final root is validated rather than blindly trusting an arbitrary path.

The IPA's alloader manifest contains 64 relative file entries totaling 5,132,560 bytes, and every listed file is present in the supplied framework tree. This confirms that the Lua runtime is a substantial bundled dependency, not a few optional scripts. The seven GXT files in the original app's top-level `TEXT/` bundle directory total approximately 9.9 MB. The launcher bootstrap uses CryptoKit SHA-256 symbols and a manifest of required files; it is therefore designed to validate source assets before provisioning rather than simply checking that a folder exists.

### What can safely be ported now

- Recreate the filesystem/bootstrap behavior in a KroSA-owned Swift component once the required source resources are legally and technically available: validate all bundled GXT inputs, provision them atomically into `Documents/TEXT`, and verify SHA-256 before accepting the result.
- Recreate the alloader provisioning as a manifest-driven operation: validate every relative path and expected byte count, reject path traversal, stage/copy the 64 files, then write the completion manifest only after all copies succeed. The original `.al_lib_manifest` is a list of relative path plus byte count separated by a tab; it does not, by itself, provide content hashes.
- Keep the original framework's ABI calls behind a narrow adapter. The disassembly does not provide enough evidence to safely construct the undocumented `ReSAIOSHostStart` configuration structure.

### Remaining blocker

This sequence recovers setup order and resource provisioning, not the engine's internal start ABI. In particular, `ReSAIOSEngineAvailable` in the supplied ReSAEngine binary still disassembles to an unconditional false return. Before enabling a Play button, we must establish whether this ReSA package is a placeholder build, whether a separate engine binary/registration step is missing, or whether the availability symbol is intentionally a permanent negative gate. A successful Swift launcher build cannot answer that question.

No GXT/game assets or ReSA binaries have been copied into the public KroSA repository. The analysis above describes files from the user-supplied IPA only.
