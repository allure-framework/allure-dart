# Contributing to Allure Dart

Thanks for helping improve the Allure Dart integrations. This repository
contains the official Allure Report packages for Dart and Flutter test
frameworks.

## Getting Started

Before opening a pull request:

1. Install Dart 3.8 or newer.
2. Install Flutter 3.24 or newer when working on `allure_flutter_test`.
3. Run `dart pub get` from the repository root.

Node.js is optional. Install Node.js 20 or newer only when you want to use the
Allure CLI locally (`npx -y allure@3`) to generate or open HTML reports, or to
run tests the same way CI does with `allure run`.

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

Use the narrowest checks that cover your change, or run the full quality script:

```bash
bash scripts/check.sh
```

That script checks formatting for package `lib`/`test` trees and `scripts/`,
then runs:

```bash
dart analyze
```

and, when Flutter is available, analyzes `allure_flutter_test`.

Before a release, also validate pub.dev packaging:

```bash
bash scripts/publish-dry-run.sh
```

CI runs that dry-run on every pull request so unconstrained dependencies and
similar publish blockers fail before tagging.

## Running Tests

The default contributor path is the normal Dart and Flutter test runners.
From the package directory:

Pure Dart packages:

```bash
dart test
```

Flutter package:

```bash
flutter test test
```

### Optional: Allure CLI reports

If you have Node.js installed and want a local HTML report or CI-like
invocation:

```bash
npx -y allure@3 run -- dart test
npx -y allure@3 generate
npx -y allure@3 open
```

CI uses `npx -y allure@3 run` for package tests.

### Optional: Allure agent mode (AI / agent workflows)

[Allure agent mode](docs/allure-agent-mode.md) is optional tooling for AI
coding agents. It wraps the same test command, keeps console output, and
adds review-oriented artifacts.

```bash
allure agent -- dart test
allure agent -- flutter test test
```

If `allure` is not on your `PATH`, use `npx -y allure@3 agent -- …` instead.

## Pull Requests

When opening a pull request:

- Keep the change focused.
- Include tests or explain why tests are not needed.
- Update package documentation when public behavior changes.
- Describe reporting behavior changes when the change affects Allure output.
- Sign the [Allure CLA](https://cla-assistant.io/accept/allure-framework/allure-dart).
- Apply **exactly one** release-notes label with the `pr:` prefix. CI rejects
  pull requests that have zero or more than one `pr:` label.

Allowed `pr:` labels:

| Label | Use when |
| --- | --- |
| `pr:new feature` | User-facing feature |
| `pr:improvement` | Enhancement that is not a new feature |
| `pr:bug` | Bug fix |
| `pr:dependencies` | Dependency-only change |
| `pr:documentation` | Docs-only change |
| `pr:security` | Security fix |
| `pr:internal` | Internal/refactors with no release-note impact |
| `pr:tests` | Test-only change (excluded from release notes) |
| `pr:invalid` | Invalid PR (excluded from release notes) |

## Good First Issues

Look for issues labeled `good first issue` or `help wanted`. If you are new to
the repository, prefer small documentation, examples, or narrowly scoped bug
fixes.

## Licensing

By contributing to this repository, you agree that your contribution is
provided under the Apache License, Version 2.0.
