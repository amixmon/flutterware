# Roadmap

Flutterware has proved that a standalone ARM64 Android app can generate, build,
sign, install, and launch a Flutter debug APK without a desktop or build server.
The next work turns that proof into a maintainable product.

## P0 — modern Android execution model

- Package executable launchers in the host APK's native-library directory.
- Keep SDK data, projects, and caches in writable app-private storage.
- Raise the host application's target SDK from the temporary API 28 setting.
- Add Android integration coverage for toolchain installation, executable path
  resolution, cancellation, and a complete debug build.
- Re-run the physical-device evidence suite on supported Android versions.

## P1 — production build modes

- Add revision-matched Android ARM64 `gen_snapshot` support.
- Produce and validate profile and release APKs.
- Define signing-key ownership and secure credential handling.
- Measure cold and warm build time, storage, and peak memory.

## P2 — plugins and extensibility

- Define the supported plugin contract and native dependency boundaries.
- Support deterministic dependency and artifact caching.
- Add compatibility fixtures for pure-Dart and Android-native plugins.
- Document unsupported plugin patterns with actionable diagnostics.

## Ongoing

- Expand the visual editor without weakening generated-source guarantees.
- Keep toolchain versions, hashes, sources, patches, and licenses auditable.
- Prefer device-tested evidence over inferred compatibility claims.
