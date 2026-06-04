#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <version> [output-file|-]" >&2
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 2
fi

version="$1"
output="${2:--}"

if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must use <MAJOR>.<MINOR>.<PATCH> format." >&2
  exit 2
fi

write_pubspec() {
  cat <<YAML
name: release_resolution_check
publish_to: none
environment:
  sdk: ^3.6.0
  flutter: '>=3.24.0'
dependencies:
  flutter:
    sdk: flutter
  allure_dart_commons: "${version}"
  allure_dart_test: "${version}"
  allure_flutter_test: "${version}"
YAML
}

if [[ "${output}" == "-" ]]; then
  write_pubspec
else
  mkdir -p "$(dirname "${output}")"
  write_pubspec > "${output}"
fi
