# Roadmap

Flutterware has proved that a standalone ARM64 Android app can generate, build,
sign, install, and launch a Flutter debug APK without a desktop or build server.
The next work turns that proof into a maintainable product.

## P0 — modern Android execution model

- [x] Package executable launchers in the host APK's native-library directory.
- [x] Keep SDK data, projects, and caches in writable app-private storage.
- [x] Raise the host application target to Android API 36.
- [x] Add Android integration coverage for toolchain installation and
  executable-path resolution.
- [ ] Add integration coverage for cancellation and a complete debug build.
- [x] Re-run the physical-device evidence suite on ARM64 Android 16.

## P1 — complete visual builder

- [x] Version project metadata so editor, theme, and dependency migrations are safe.
- [ ] Expand the catalog to broad Material 3 component coverage with preview,
  properties, events, persistence, and generated-code parity.
- [x] Add a project Theme Studio for light, dark, and system modes, seeded color
  schemes, typography, shapes, and component themes.
- [ ] Add representative generated-app fixtures for forms, navigation, responsive
  dashboards, and data-driven screens.

## P2 — packages and extensibility

- [x] Add Pub search, package details, version selection, and deterministic
  dependency editing.
- [ ] Add lockfile/cache management and offline reuse.
- [x] Classify pure-Dart, Flutter-only, and Android-plugin packages before install.
- [ ] Support curated visual adapters for package-provided widgets.
- [ ] Define the Android plugin/native dependency boundary with actionable errors.
- [ ] Add compatibility fixtures for pure-Dart and Android-native plugins.

## P3 — production build modes

- Add revision-matched Android ARM64 `gen_snapshot` support.
- Produce and validate profile and release APKs.
- Define signing-key ownership and secure credential handling.
- Measure cold and warm build time, storage, and peak memory.

## Ongoing

- Expand the visual editor without weakening generated-source guarantees.
- Keep toolchain versions, hashes, sources, patches, and licenses auditable.
- Prefer device-tested evidence over inferred compatibility claims.
