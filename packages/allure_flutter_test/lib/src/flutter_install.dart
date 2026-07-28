import 'package:allure_dart_commons/allure_dart_commons.dart';
import 'package:allure_dart_test/allure_dart_test.dart'
    show AllureTestRuntimePlugin;
import 'package:flutter/widgets.dart';
import 'package:integration_test/integration_test.dart';

import 'flutter_golden_hook_stub.dart'
    if (dart.library.io) 'flutter_golden_hook.dart';
import 'flutter_screenshot_hook.dart';

bool _screenshotOnFailureEnabled = false;
bool _goldenDiffAttachEnabled = false;

/// Installs the Allure runtime plugin for Flutter tests.
///
/// [autoScreenshotOnFailure] and [autoAttachGoldenDiff] are opt-in,
/// process-wide hooks and are monotonic: once enabled by any call, later
/// calls that omit the flag (leaving it at its default `false`) never
/// disable it again.
void installAllure({
  AllureLifecycle? lifecycle,
  bool autoScreenshotOnFailure = false,
  bool autoAttachGoldenDiff = false,
}) {
  AllureTestRuntimePlugin.ensureInstalled(
    lifecycle: lifecycle,
    frameworkLabelResolver: _resolveFrameworkLabel,
  );

  if (autoScreenshotOnFailure && !_screenshotOnFailureEnabled) {
    _screenshotOnFailureEnabled = true;
    installScreenshotOnFailureHook();
  }
  if (autoAttachGoldenDiff && !_goldenDiffAttachEnabled) {
    _goldenDiffAttachEnabled = true;
    installGoldenDiffHook();
  }
}

String _resolveFrameworkLabel() {
  final binding = WidgetsBinding.instance;
  if (binding is IntegrationTestWidgetsFlutterBinding) {
    return 'flutter-integration-test';
  }
  return 'flutter-test';
}
