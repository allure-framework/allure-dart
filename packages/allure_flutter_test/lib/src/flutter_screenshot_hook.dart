/// Opt-in auto screenshot-on-failure hook for the Flutter Allure adapter.
///
/// Installed by `installAllure(autoScreenshotOnFailure: true)`. It wraps
/// `flutter_test`'s [ft.reportTestException] to remember that the current
/// test failed, then registers a raw `flutter_test` `tearDown` (not the
/// Allure-wrapped fixture tearDown) that captures a screenshot of the
/// current widget tree and attaches it to the still-open Allure test result.
library;

import 'dart:ui' as ui;

import 'package:allure_dart_commons/allure_dart_commons.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_test/flutter_test.dart' as ft;

bool _installed = false;
bool _pendingFailure = false;

/// Installs the screenshot-on-failure hook, once per process.
///
/// Safe to call more than once: only the first call installs anything.
void installScreenshotOnFailureHook() {
  if (_installed) {
    return;
  }
  _installed = true;

  final previousReporter = ft.reportTestException;
  ft.reportTestException = (details, testDescription) {
    _pendingFailure = true;
    previousReporter(details, testDescription);
  };

  // A raw `tearDown` runs before the Allure runtime plugin's own
  // fixture-wrapped `tearDown` (registered earlier, in `installAllure`),
  // since `package:test` tearDowns run in reverse declaration order. That
  // ordering lets the screenshot attach to the test result before it is
  // stopped and written.
  ft.tearDown(_captureScreenshotOnFailure);
}

Future<void> _captureScreenshotOnFailure() async {
  // Cleared unconditionally so a retried test starts the next attempt with
  // a fresh flag, regardless of whether this capture succeeds.
  final shouldCapture = _pendingFailure;
  _pendingFailure = false;
  if (!shouldCapture || !ft.canCaptureImage) {
    return;
  }

  try {
    await ft.TestWidgetsFlutterBinding.instance.runAsync(() async {
      final element = WidgetsBinding.instance.rootElement;
      if (element == null) {
        return;
      }
      final image = await ft.captureImage(element);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) {
          return;
        }
        await attachment(
          'screenshot-on-failure',
          bytes.buffer.asUint8List(),
          contentType: 'image/png',
          fileExtension: 'png',
        );
      } finally {
        image.dispose();
      }
    });
  } catch (_) {
    // Best-effort: a screenshot capture failure must never mask the
    // original test failure that triggered it.
  }
}
