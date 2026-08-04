# Contributing to Flutterware

Thanks for helping make full Flutter development possible on Android devices.

## Before opening a change

- Search the issues and existing pull requests for related work.
- Open an issue before large architectural changes so implementation effort is
  not duplicated.
- Keep changes focused. Toolchain, runtime, editor, and documentation changes
  should normally be separate pull requests.
- Do not commit credentials, signing keys, generated APKs, build directories,
  device identifiers, or raw device logs containing personal information.

## Development setup

The primary application lives in `apps/fluttware_flutter`. Install a Flutter
SDK compatible with the version in its `pubspec.yaml`, then run:

```bash
cd apps/fluttware_flutter
flutter pub get
flutter analyze
flutter test
```

The native proof of concept and reproducible toolchain preparation scripts are
under `poc/android-runner`. See `poc/README.md` before changing toolchain
artifacts or making device-compatibility claims.

## Branch and pull-request workflow

This repository uses GitHub Flow:

1. Branch from the latest `main` using `feature/<topic>`, `fix/<topic>`,
   `docs/<topic>`, or `chore/<topic>`.
2. Commit cohesive changes using an imperative summary, such as
   `feat: package runtime launchers as native libraries`.
3. Open a pull request early. Mark it as a draft while work is incomplete.
4. Keep the branch current with `main`, address review, and ensure CI passes.
5. Squash-merge after approval. Delete the merged branch.

`main` is the protected, releasable branch. Direct pushes should be reserved
for repository bootstrap or urgent maintainer recovery.

## Pull-request expectations

A pull request should explain the problem, the approach, tests performed, and
any Android versions or devices used. UI changes should include screenshots.
On-device claims should include a sanitized log under `evidence/device` only
when that evidence is intentionally approved for publication.

Generated source must remain deterministic. Files under a generated project's
`lib/generated` directory are owned by the generator; user-authored code belongs
under `lib/custom` and must never be overwritten.
