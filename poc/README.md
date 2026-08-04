# Proof-of-concept guide

The large toolchain ZIPs under the POC app's asset directory are generated and
not tracked because identical bundles ship with the Flutter application. Run
the preparation commands below when building the standalone POC from a fresh
clone.

## Termux pipeline probe

The Termux probe is intentionally an evaluator, not a blind installer. Toolchain
ports evolve rapidly, and executing an unpinned community binary installer is
not a sound basis for evidence.

Prerequisites for the maximum test surface:

- ARM64 Android and a maintained Termux installation;
- Android-built Dart and patched Flutter SDK matching one engine revision;
- OpenJDK 17 or 21 and Gradle 9.1 for the Flutter 3.44 template used in the
  August 2026 control run;
- Android platform `android.jar` and build-tool JARs;
- ARM64/Bionic `aapt2` and `zipalign`;
- ARM64/Bionic Flutter host tools (`gen_snapshot`, `impellerc`, and
  `font-subset`, or the documented feature workarounds).

`probe.sh` creates a timestamped workspace below
`$HOME/.local/share/fluttware/workspace`. It does not alter an existing Flutter
project. The summary uses these exit codes:

- `0`: command succeeded;
- `125`: deliberately skipped because a prerequisite output/tool was absent;
- any other code: the tool's real exit code.

The generated tests are:

1. device, mount, memory, storage, PATH, and binary-format inventory;
2. `dart --version`, Android ABI reporting, child process execution;
3. `dart compile kernel`, `dart compile exe`, then running the result;
4. `flutter --version`, `flutter doctor -v`, and `flutter create`;
5. online then offline `flutter pub get` using the same cache;
6. debug, profile, and release ARM64 APK builds;
7. APK signature verification;
8. optional user-mediated installation.

The default release/profile commands disable icon tree shaking because the
current independent Termux port documents `font-subset`/JIT issues. Remove
`--no-tree-shake-icons` after installing and proving a Bionic `font-subset`.

## Native Android process runner

`android-runner` is a minimal Java/Android Gradle project. It has no AndroidX or
UI-library dependencies. The app:

- starts an executable with an argument-per-line UI;
- sets private `HOME`, `TMPDIR`, and a restricted `PATH`;
- uses the app-private directory as the working directory;
- drains stdout and stderr concurrently;
- reports exit code and elapsed time;
- supports cooperative then forced cancellation;
- stages a selected APK using `PackageInstaller` and surfaces Android's user
  confirmation screen.

Build it using a Gradle-capable on-device environment:

```bash
cd poc/android-runner
gradle :app:assembleDebug \
  -Pandroid.aapt2FromMavenOverride=/data/data/com.termux/files/usr/bin/aapt2
```

Version `0.5-jdk-gradle-probe` bundles a minimal Android/ARM64 Dart SDK, a
version-pinned patched Flutter 3.44.8 command-line tool, and an Android/ARM64
OpenJDK 21 runtime. It creates a Flutter Android project, resolves Pub packages
online/offline, and downloads then runs Gradle 9.1.0 online/offline. It does
**not** yet bundle the Android SDK/build tools or Flutter engine host
executables, so it cannot build a new APK yet.

The executable-cache experiment deliberately targets API 28. Apps targeting
API 29+ cannot generally place a downloaded ELF under writable app storage,
call `chmod +x`, and execute it. A production-target Fluttware design will need
to package executable ELF files as native APK libraries, or retain the legacy
target only for a sideloaded research build and accept its security and store
distribution limitations.

### Sketchware-style asset execution probe

The runner now also contains a deliberately isolated legacy-target experiment.
It follows Sketchware Pro's execution model:

1. package an Android/Bionic ARM64 PIE in APK assets;
2. copy it to `cacheDir`;
3. verify it with SHA-256 and apply mode `0700`;
4. execute it with `ProcessBuilder`;
5. capture stdout, stderr, exit status, environment, working directory, and a
   child-created proof file.

The experimental APK targets API 28 because writable-app-home execution is
rejected for apps targeting API 29+. It is a sideloaded research build, not the
production packaging design.

Build the native asset and APK:

```bash
export ANDROID_NDK_ROOT=/path/to/Android/Sdk/ndk/<version>
poc/android-runner/native-probe/build-arm64.sh
gradle -p poc/android-runner :app:assembleDebug
```

Install and launch it:

```bash
adb install -r poc/android-runner/app/build/outputs/apk/debug/app-debug.apk
adb shell am start -W -n dev.fluttware.runner/.MainActivity
adb shell run-as dev.fluttware.runner \
  cat files/workspace/native-probe-output.txt
```

The probe auto-runs on launch. Its exact first physical-device result is in
`evidence/device/00_sketchware_asset_exec.log`.

### Bundled Dart SDK probe

This milestone follows the same local-only pattern:

1. package a minimal Android/Bionic ARM64 Dart SDK as an APK asset;
2. calculate the asset SHA-256 before trusting it;
3. extract it below `files/toolchains/` and apply mode `0700` to its ELF files;
4. set private `HOME`, `TMPDIR`, `PUB_CACHE`, `PATH`, and workspace values;
5. run `dart --version`;
6. execute a Dart source file that starts a child process and writes a file;
7. run `dart compile kernel` and execute the resulting `.dill` file;
8. reuse the extracted SDK on later launches when its hash matches.

The POC uses the Termux ARM64 Dart 3.12.2 package. To reproduce the SDK ZIP
from the original package:

```bash
curl -LO \
  https://packages.termux.dev/apt/termux-main/pool/main/d/dart/dart_3.12.2_aarch64.deb
poc/android-runner/dart-sdk/prepare-termux-dart.sh \
  ./dart_3.12.2_aarch64.deb
```

The preparation script refuses a package whose SHA-256 is not
`42690fbaa64a9d9efb62a0dbcaef4d055846ebacc446ecb586ec4ec8953a2161`.
It copies only the VM, AOT runtime, Dart developer/kernel snapshots, platform
kernel, licence, version, and revision. The generated ZIP is about 32 MB; the
minimal installed SDK is about 85 MB.

Build and install the current app:

```bash
gradle -p poc/android-runner :app:assembleDebug
adb install -r \
  poc/android-runner/app/build/outputs/apk/debug/app-debug.apk
adb shell am force-stop dev.fluttware.runner
adb shell am start -W -n dev.fluttware.runner/.MainActivity
adb logcat -d -s FluttwareRunner:I '*:S'
```

Both native and Dart probes start automatically. A successful Dart run ends
with all of these lines:

```text
Dart SDK version: 3.12.2 ... on "android_arm64"
FLUTTWARE_DART_SOURCE_OK
FLUTTWARE_DART_CHILD_PROCESS_OK
FLUTTWARE_DART_STEP_COMPILE_KERNEL
FLUTTWARE_DART_STEP_RUN_KERNEL
FLUTTWARE_DART_ALL_STEPS_OK
dart.exit=0
dart.kernel.exists=true
dart.proof=FLUTTWARE_DART_FILE_WRITE_OK
```

The physical-device result, including cold extraction and warm cache reuse, is
in `evidence/device/01_dart_sdk.log`.

This proves the Android Dart VM and front-end kernel compiler work inside the
standalone app. The next section extends that result through the Flutter CLI
and Pub.

### Bundled Flutter CLI and Pub probe

The stock cached `flutter_tools.snapshot` cannot load in the Android ARM64 VM:
it is an AOT snapshot for a Linux x64 VM configuration. Fluttware recompiles
Flutter Tools as a portable kernel `.dill` and applies the small, auditable
[`android-host.patch`](android-runner/flutter-tool/android-host.patch). The
patch suppresses unsupported Android-host cache updates and reads immutable
version metadata without Git. A fail-closed Git shim exits with an error if it
is ever executed; it does not invent repository information.

To reproduce the Flutter asset, first install Flutter 3.44.8 on the development
machine. Then run:

```bash
poc/android-runner/flutter-tool/prepare-flutter-tool.sh /path/to/flutter
```

The script checks for exactly Flutter 3.44.8 and Dart 3.12.2, compiles the
portable tool kernel, bundles the pinned templates and SDK packages, tests the
ZIP, and places it in the Android app's asset directory. It requires `bash`,
`jq`, `patch`, `zip`, and the matching Flutter SDK. Build and install the app
with the commands in the preceding section.

On launch, tap **Run Flutter probes**, or allow the automatic Dart probe to
finish. The app then performs:

```text
flutter --version
flutter create --platforms=android --no-pub --empty --overwrite flutter_cli_project
flutter pub get
flutter pub get --offline
```

A complete pass ends with:

```text
FLUTTWARE_FLUTTER_VERSION_EXIT=0
FLUTTWARE_FLUTTER_CREATE_EXIT=0
FLUTTWARE_FLUTTER_PROJECT_FILES_OK
FLUTTWARE_FLUTTER_PUB_ONLINE_EXIT=0
FLUTTWARE_FLUTTER_PUB_OFFLINE_EXIT=0
FLUTTWARE_FLUTTER_ALL_STEPS_OK
flutter.exit=0
flutter.project.main=true
flutter.project.gradleWrapper=true
flutter.project.packageConfig=true
```

The exact stock failure, intermediate missing-file failures, cold extraction,
online resolution, offline reuse, and warm relaunch are preserved in
[`evidence/device/02_flutter_cli.log`](../evidence/device/02_flutter_cli.log).

That Flutter/Pub result is the v0.4 boundary. The following v0.5 milestone adds
Java and the Gradle runtime.

### Bundled OpenJDK and Gradle probe

Download these exact Android/ARM64 Termux packages on the development machine:

```bash
mkdir -p fluttware-jdk-downloads
cd fluttware-jdk-downloads
base=https://packages-cf.termux.dev/apt/termux-main/pool/main
curl -fLO "$base/o/openjdk-21/openjdk-21_21.0.12_aarch64.deb"
curl -fLO "$base/liba/libandroid-shmem/libandroid-shmem_0.7_aarch64.deb"
curl -fLO "$base/liba/libandroid-spawn/libandroid-spawn_0.3_aarch64.deb"
curl -fLO "$base/libi/libiconv/libiconv_1.18-1_aarch64.deb"
curl -fLO "$base/z/zlib/zlib_1.3.2_aarch64.deb"
curl -fLO "$base/libc/libc++/libc++_29_aarch64.deb"
cd ..
```

Create the checked Android asset:

```bash
poc/android-runner/jdk/prepare-termux-openjdk.sh \
  fluttware-jdk-downloads/openjdk-21_21.0.12_aarch64.deb \
  fluttware-jdk-downloads/libandroid-shmem_0.7_aarch64.deb \
  fluttware-jdk-downloads/libandroid-spawn_0.3_aarch64.deb \
  fluttware-jdk-downloads/libiconv_1.18-1_aarch64.deb \
  fluttware-jdk-downloads/zlib_1.3.2_aarch64.deb \
  fluttware-jdk-downloads/libc++_29_aarch64.deb
```

The script verifies all six SHA-256 values before extracting anything. It
keeps the complete Java runtime image and the `java`, `javac`, `jar`,
`jarsigner`, and `keytool` launchers. The resulting APK asset is about 62 MB
compressed and 174 MB installed. Build and install the app using the commands
above, then tap **Run Java/Gradle** or let the automatic sequence finish.

The app runs:

```text
java --version
javac -version
GradleWrapperMain --no-daemon --version
GradleWrapperMain --offline --no-daemon --version
```

A successful run ends with:

```text
FLUTTWARE_JAVA_VERSION_EXIT=0
FLUTTWARE_JAVAC_VERSION_EXIT=0
FLUTTWARE_GRADLE_ONLINE_EXIT=0
FLUTTWARE_GRADLE_OFFLINE_EXIT=0
FLUTTWARE_JDK_GRADLE_ALL_STEPS_OK
jdk.exit=0
```

Flutter 3.44.8 generates a Gradle 9.1.0 `-all` wrapper. Its first private
download/cache used about 758 MB on the tested phone; later runs reuse it. The
exact missing-`libc++_shared.so` failure, corrected run, hashes, timings, and
storage readback are in
[`evidence/device/03_jdk_gradle.log`](../evidence/device/03_jdk_gradle.log).

### Direct APK build without Gradle

Fluttware now follows Sketchware Pro's custom compiler pipeline for generated
applications. The runner bundles an Android SDK platform, Bionic ARM64 AAPT2,
D8, and apksigner, then runs:

```text
generated manifest/resources/Java
  -> aapt2 compile + link
  -> javac
  -> D8
  -> ZIP/JAR package assembly
  -> keytool development key (first run only)
  -> apksigner sign + verify
  -> Android PackageInstaller
```

Tap **Build APK (no Gradle)**. The result is
`files/workspace/app.apk`; tap **Install APK** and accept Android's confirmation.
On the physical SM-A356E the warm build took 6.6 seconds, v2/v3 verification
passed, the package installed, launched, and rendered `FLUTTWARE DIRECT APK OK`.
The exact log and development failures are in
[`evidence/device/04_direct_android_apk.log`](../evidence/device/04_direct_android_apk.log).

Version 0.17 completes the Flutter debug milestone. It adds a 32 MB compressed,
revision-matched debug toolchain asset and automatically runs:

```text
Flutter project + package_config.json
  -> Android/ARM64 frontend_server -> app.dill
  -> flutter_assets/kernel_blob.bin + debug snapshots
  -> prebuilt embedding dex + stripped ARM64 libflutter.so
  -> AAPT2 resource APK + direct ZIP assembly
  -> apksigner verify -> flutter-app.apk
```

The first fresh extraction plus build completed in 27.6 seconds on the
SM-A356E. The 40.6 MB APK installed, cold-launched in 2.98 seconds, and rendered
Flutter's `Hello World!`. See
[`evidence/device/05_direct_flutter_debug_apk.log`](../evidence/device/05_direct_flutter_debug_apk.log).
Gradle and AGP are not on the generated-project critical path. Profile/release
still require an Android/Bionic ARM64 `gen_snapshot`, and plugins need a
controlled manifest/resource/dependency merger.
