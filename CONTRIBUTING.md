# Contributing to Allure Dart

Thanks for helping improve the Allure Dart integrations. This repository
contains the official Allure Report packages for Dart and Flutter test
frameworks.

## Getting Started

Before opening a pull request:

1. Install Dart 3.6 or newer.
2. Install Flutter 3.24 or newer when working on `allure_flutter_test`.
3. Run `dart pub get` from the repository root.
4. Read `docs/allure-agent-mode.md` before adding, changing, or validating
   tests.

For local Flutter adapter development, create local workspace overrides before
running `flutter pub get`:

```bash
bash scripts/setup-flutter-workspace.sh
cd packages/allure_flutter_test
flutter pub get
```

Remove the generated override before publishing the Flutter package:

```bash
rm packages/allure_flutter_test/pubspec_overrides.yaml
```

## Repository Layout

- `packages/allure_dart_commons` contains the framework-neutral lifecycle,
  model, writer, and runtime APIs.
- `packages/allure_dart_test` contains the adapter for Dart `package:test`.
- `packages/allure_flutter_test` contains the adapter for Flutter widget tests
  and host-run `integration_test` suites.

## Development Checks

Use the narrowest checks that cover your change:

```bash
dart format .
dart analyze
```

For test-related work, run tests through Allure agent mode as described in
`docs/allure-agent-mode.md`. Agent mode preserves console output and adds
runtime evidence that makes review easier.

Pure Dart packages:

```bash
allure agent -- dart test
```

Flutter package:

```bash
allure agent -- flutter test test
```

## Pull Requests

When opening a pull request:

- Keep the change focused.
- Include tests or explain why tests are not needed.
- Update package documentation when public behavior changes.
- Describe runtime evidence when the change affects reporting output.

## Licensing

By contributing to this repository, you agree that your contribution is
provided under the Apache License, Version 2.0.
