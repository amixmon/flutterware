# Flutterware — Flutter builds entirely on Android

> [!WARNING]
> Flutterware is an experimental prototype, not a production-ready IDE. The
> current host app temporarily targets Android API 28 to run compiler launchers
> from writable storage. Do not use its generated debug signing key for
> production applications.

Verdict: **technically feasible on ARM64 Android, but not with the unmodified
official Flutter Linux archive**.

A complete local APK pipeline has three practical forms:

1. A Bionic-native Termux toolchain with Android-built Dart, Flutter host tools,
   `gen_snapshot`, and Android build tools. This is the most capable current
   route and can produce debug, profile, and release ARM64 APKs.
2. A glibc Linux userspace under `proot`, combined with Android-compatible
   build tools. This accepts more stock Linux binaries but is slower and still
   needs non-stock ARM64 Android build tools.
3. A dedicated Android IDE app that packages every executable in its APK's
   native-library area and treats the downloaded SDK/framework/cache as data.
   This is productizable, but Android's W^X rules prevent a modern app from
   simply downloading executables into `files/` and invoking them.

The detailed findings, architecture, complete binary matrix, resource budget,
and evidence classification are in the
[feasibility report](docs/feasibility-report.md).

The product prototype lives in [`apps/fluttware_flutter`](apps/fluttware_flutter).
See the [roadmap](docs/roadmap.md) for planned milestones and
[contributing guide](CONTRIBUTING.md) for the branch and pull-request workflow.
Bundled compilers, SDK files, and their licensing provenance are described in
the [third-party component notice](THIRD_PARTY.md).

After cloning, fetch the pinned Android ARM64 toolchain release before building
the host application:

```bash
tools/fetch_toolchains.sh
```

## License

Flutterware's original source and documentation are licensed under the
[Apache License 2.0](LICENSE). Bundled third-party components remain under
their respective upstream licenses.

## Proof of concept

- [`poc/termux/probe.sh`](poc/termux/probe.sh) exercises Dart, Flutter, pub,
  APK builds, explicit re-signing/verification, cache reuse, and optional installation on
  a real Android/Termux device. Every command receives its own raw log.
- [`poc/android-runner`](poc/android-runner) is a native Android app that tests
  process execution, environment configuration, working directories, pipe
  capture, cancellation, a native Android Dart SDK, a patched Flutter CLI,
  project creation, online/offline Pub resolution, OpenJDK 21, online/offline
  Gradle 9.1 execution, and a Sketchware-style direct AAPT2/javac/D8/sign/install
  pipeline. Version 0.17 also compiles a real Flutter debug kernel, packages
  the ARM64 engine/embedding, signs the APK, and launches Flutter without using
  Gradle for the generated project.
- [`evidence/host`](evidence/host) contains the Linux x64 control run made in
  this workspace. It proves the test sequence, not Android compatibility.
- [`evidence/device`](evidence/device) contains the physical ARM64 Android 16
  results for native process execution, Dart 3.12.2, Flutter 3.44.8, Pub,
  OpenJDK 21, Gradle research, and the direct no-Gradle APK build/install/run.

The current standalone runner APK is
[`poc/android-runner/app/build/outputs/apk/debug/app-debug.apk`](poc/android-runner/app/build/outputs/apk/debug/app-debug.apk).
It has been installed and exercised on a Samsung SM-A356E. Version 0.17 builds,
signs, installs, and launches a real Flutter debug APK locally without Gradle.
The generated application cold-launched and rendered `Hello World!`; the exact
device log is [`05_direct_flutter_debug_apk.log`](evidence/device/05_direct_flutter_debug_apk.log).
Profile/release AOT and general plugin support remain future work.

## Run the Android probe

Install or provide an Android/Bionic-compatible toolchain first. The report
explains why copying the stock Linux SDK is insufficient. Then, in Termux:

```bash
cd /path/to/fluttware
source poc/termux/env.sh
poc/termux/probe.sh
```

To ask Android's package installer to install the produced APK:

```bash
poc/termux/probe.sh --install
```

Installation is intentionally opt-in and remains user-confirmed. To re-sign an
APK explicitly:

```bash
poc/termux/resign_apk.sh input.apk output.apk
```

The keystore password defaults to the conventional local-development value
`android`. Set `FLUTTWARE_KEYSTORE_PASSWORD` before invoking the script for a
non-test key; never use this generated key as an unattended production secret.

## Evidence status

The proof app was tested through ADB on a physical ARM64 Android 16 device.
Evidence in the report is classified as:

- `upstream`: supported by source code or official documentation;
- `independent`: reported by a named open-source project with its exact build;
- `device-tested`: executed by this repository's standalone app on the named
  physical device;
- `pending`: a later build-pipeline stage that has not yet run on the device.

Nothing from the Linux host control run is presented as an Android result.
Device-side Java, Gradle-runtime, direct APK build, signing, installation, and
launch claims are backed by separate physical-device logs.
