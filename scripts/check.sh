#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${root}"

# Format only source trees. Avoid package-root walks that pick up local
# allure-results attachment sources and other generated artifacts.
format_paths=(
  packages/allure_dart_commons/lib
  packages/allure_dart_commons/test
  packages/allure_dart_test/lib
  packages/allure_dart_test/test
  packages/allure_flutter_test/lib
  packages/allure_flutter_test/test
  scripts
)

echo "==> dart format"
dart format --output=none --set-exit-if-changed "${format_paths[@]}"

echo "==> dart analyze"
dart analyze

if command -v flutter >/dev/null 2>&1; then
  echo "==> flutter workspace overrides"
  bash scripts/setup-flutter-workspace.sh

  echo "==> flutter pub get"
  (
    cd packages/allure_flutter_test
    flutter pub get
  )

  echo "==> flutter analyze"
  (
    cd packages/allure_flutter_test
    flutter analyze --no-fatal-infos
  )
else
  echo "==> skipping flutter analyze (flutter not on PATH)"
fi

echo "==> checks passed"
