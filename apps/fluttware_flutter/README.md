# Flutterware Flutter host prototype

This is the separate, lightweight Flutter UI experiment for Flutterware. It does
not replace or modify `poc/android-runner`, which remains the verified native
on-device build proof.

From the repository root, run `tools/fetch_toolchains.sh` before the first
Android build. It downloads the version-pinned ARM64 toolchain archives from
the project's GitHub Release and verifies every SHA-256 checksum before placing
them in this app's asset tree.

The prototype currently includes:

- One shared Material 3 light/dark design system with matching system bars
- Persistent projects dashboard and a dedicated project-creation page
- A responsive visual editor with a collapsible Sketchware-style widget palette
- Tap-to-add and long-press drag/drop, selection, properties, delete, undo/redo
- 23 core Flutter widgets across layout, content, input, scrolling and feedback
- AppBar and FloatingActionButton screen slots with toggle, edit and remove
- A persisted, Sketchware-style counter logic block that regenerates Dart
- A real project file tree with read-only generated code and editable custom code
- Real native build progress, streamed logs, APK installation, and launch
- No third-party runtime packages

## Source layout

```text
lib/
├── app/                         # App root, global theme and system UI
├── features/
│   ├── projects/
│   │   ├── data/                # Native project persistence bridge
│   │   ├── domain/              # Project model
│   │   └── presentation/        # Dashboard and create-project page
│   ├── editor/presentation/     # Simple visual editor
│   └── build/presentation/      # Build/install progress sheet
├── runtime/                     # Flutter-to-native runtime controller
└── ui/
    ├── theme/                   # Colors, dimensions and component themes
    └── widgets/                 # Shared button, field, card and color picker

android/app/src/main/
├── kotlin/dev/fluttware/app/    # Runtime service, process/build and install code
├── java/dev/fluttware/runner/   # Toolchain installers reused from the native POC
├── assets/                      # ARM64 toolchains and direct-build scripts
└── res/                         # Launch and system-bar colors for light/dark mode
```

`main.dart` starts `FlutterwareApp`. The app root applies `AppTheme` and the
glow-free scroll behavior. Feature pages call `ProjectRepository` and
`RuntimeController`; those classes cross the Flutter platform channel into the
Kotlin host. Kotlin persists project JSON, installs the bundled toolchain,
generates/builds the child Flutter APK, asks Android to install it, and launches
the installed child app.

## Generated project contract

Each project is a real Flutter package under the app's internal `files/projects`
directory. `.fluttware/design.json` and `.fluttware/logic.json` are the visual
source of truth. `lib/main.dart` and `lib/generated/` are regenerated from those
models and are read-only in the code editor. `lib/custom/` is owned by the user
and is never overwritten by the generator.

The starter model generates a Material 3 app with the selected seed color, an
AppBar, counter text, and an increment FloatingActionButton. The Logic tab's
`Change counter by` block updates the JSON model and the generated Dart source.
The DEBUG banner remains visible.

The visual editor uses a typed widget tree rather than absolute coordinates.
This preserves Flutter's Row/Column/Stack constraint rules. The catalog is a
registry, so additional core, plugin and custom widgets can be added without
changing the editor canvas.

Build details can be swiped down while the native foreground build continues.
A compact, smoothly animated progress panel remains above the editor bottom
bar and reopens the logs when tapped. Run changes to Stop during a build.

Reusable UI belongs in `lib/ui/widgets`. Pages should use `AppButton`,
`AppTextField`, and `AppSectionCard` instead of defining new button, field, or
card styling. App-wide visual changes belong in `AppTheme`; spacing/radius
changes belong in `app_tokens.dart`.

The generated application is currently an ARM64 Flutter debug APK and keeps the
Flutter DEBUG banner visible. The host temporarily targets Android API 28 so
Android permits executing compiler launchers from writable internal storage.
Moving those launchers to `nativeLibraryDir` is required before adopting a
modern production target SDK.
