#!/usr/bin/env bash
# Validate that packages can be published to pub.dev.
# Fails on pub publish warnings (for example unconstrained dependencies).
#
# Flutter dry-run uses local path overrides for sibling packages. Those
# overrides are pubignored and are required when dependency versions are
# bumped in-repo before they exist on pub.dev.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${root}"

echo "==> dart pub get (workspace)"
dart pub get

for package in allure_dart_commons allure_dart_test; do
  echo "==> dart pub publish --dry-run (${package})"
  (
    cd "packages/${package}"
    dart pub publish --dry-run
  )
done

echo "==> flutter workspace overrides for Flutter dry-run"
bash scripts/setup-flutter-workspace.sh

echo "==> flutter pub get (allure_flutter_test)"
(
  cd packages/allure_flutter_test
  flutter pub get
)

echo "==> flutter pub publish --dry-run (allure_flutter_test)"
(
  cd packages/allure_flutter_test
  # Prefer flutter pub so local Flutter SDK resolution matches CI publishers.
  if ! flutter pub publish --dry-run; then
    echo "allure_flutter_test publish dry-run failed" >&2
    exit 1
  fi
)

echo "==> publish dry-run passed"
