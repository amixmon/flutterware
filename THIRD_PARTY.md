# Third-party components

Flutterware bundles a version-pinned ARM64 Android toolchain so builds can run
entirely on the device. Those archives are not covered by Flutterware's project
license. Each component remains under its upstream license.

| Component | Version/source | Bundled archive |
|---|---|---|
| Dart SDK for Android | Dart 3.12.2 from the hash-pinned Termux package | `dart-sdk-3.12.2-android-arm64.zip` |
| Flutter framework and tools | Flutter 3.44.8 with the documented Android-host patch | `flutter-tool-3.44.8-android-arm64.zip` |
| Flutter debug engine artifacts | Flutter 3.44.8 revision-matched artifacts | `flutter-debug-3.44.8-android-arm64.zip` |
| OpenJDK and compatibility libraries | OpenJDK 21.0.12 and hash-pinned Termux packages | `openjdk-21.0.12-android-arm64.zip` |
| Android SDK and build tools | Android API/build-tools 36 plus hash-pinned Termux AAPT2 dependencies | `android-sdk-36-arm64.zip` |

The archives are distributed as assets of the
`toolchain-3.44.8-android-arm64-v1` GitHub Release instead of being stored in
Git history. `tools/fetch_toolchains.sh` downloads them into
`apps/fluttware_flutter/android/app/src/main/assets` and rejects any checksum
mismatch. License, legal, and notice files supplied by upstream are retained
inside the archives. Exact source packages, checksums, retained files, and
reproduction commands are documented in [`poc/README.md`](poc/README.md) and
implemented by the scripts under `poc/android-runner`.

The `Sketchware-Pro-main` directory and its downloaded ZIP are local research
references and are intentionally excluded from this repository. Sketchware Pro
is linked and credited in the feasibility report; no copy of its source is part
of Flutterware's commit history.

Contributors adding or updating a bundled artifact must include:

- the upstream project and download location;
- the exact version and SHA-256 checksum;
- all required license and notice files;
- a reproducible preparation script; and
- physical-device evidence for compatibility claims.
