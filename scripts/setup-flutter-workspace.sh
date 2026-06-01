#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

cat > packages/allure_flutter_test/pubspec_overrides.yaml <<'YAML'
dependency_overrides:
  allure_dart_commons:
    path: ../allure_dart_commons
  allure_dart_test:
    path: ../allure_dart_test
YAML

echo "Created packages/allure_flutter_test/pubspec_overrides.yaml"
echo "Run this before Flutter adapter development and delete the file before publishing."
