#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <version> <commons|dart-test> [output-file|-]" >&2
}

if [[ $# -lt 2 || $# -gt 3 ]]; then
  usage
  exit 2
fi

version="$1"
scope="$2"
output="${3:--}"

if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must use <MAJOR>.<MINOR>.<PATCH> format." >&2
  exit 2
fi

write_commons_pubspec() {
  cat <<YAML
name: release_resolution_check
publish_to: none
environment:
  sdk: ^3.6.0
dependencies:
  allure_dart_commons: "${version}"
YAML
}

write_dart_test_pubspec() {
  cat <<YAML
name: release_resolution_check
publish_to: none
environment:
  sdk: ^3.6.0
dependencies:
  allure_dart_commons: "${version}"
  allure_dart_test: "${version}"
YAML
}

write_pubspec() {
  case "${scope}" in
    commons)
      write_commons_pubspec
      ;;
    dart-test)
      write_dart_test_pubspec
      ;;
    *)
      echo "Unknown scope ${scope}. Expected commons or dart-test." >&2
      exit 2
      ;;
  esac
}

if [[ "${output}" == "-" ]]; then
  write_pubspec
else
  mkdir -p "$(dirname "${output}")"
  write_pubspec > "${output}"
fi
