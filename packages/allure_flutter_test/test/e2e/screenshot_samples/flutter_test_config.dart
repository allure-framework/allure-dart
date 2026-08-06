/// Directory-scoped Flutter test configuration that enables the opt-in
/// auto screenshot-on-failure hook for samples in this directory.
///
/// The Flutter test framework walks up from a test file's own directory
/// looking for `flutter_test_config.dart` and stops at the first match, so
/// this file only applies to samples under `test/e2e/screenshot_samples/`
/// and does not affect other e2e samples or `test/samples/`.
library;
import 'dart:async';

import 'package:allure_flutter_test/allure_flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  installAllure(autoScreenshotOnFailure: true);
  await testMain();
}
