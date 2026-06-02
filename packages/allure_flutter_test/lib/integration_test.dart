/// Integration-test exports with the Allure Flutter drop-in test wrappers.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart' as ft;

import 'src/flutter_test_drop_in.dart' as drop_in;

export 'package:flutter_test/flutter_test.dart'
    hide test, group, setUp, tearDown, setUpAll, tearDownAll, testWidgets;
export 'package:integration_test/integration_test.dart';
export 'allure_flutter_test.dart';

/// Drop-in replacement for `flutter_test`'s `test` with Allure reporting.
void test(
  Object? description,
  dynamic Function() body, {
  String? testOn,
  ft.Timeout? timeout,
  Object? skip,
  Object? tags,
  Map<String, dynamic>? onPlatform,
  int? retry,
}) {
  drop_in.test(
    description,
    body,
    testOn: testOn,
    timeout: timeout,
    skip: skip,
    tags: tags,
    onPlatform: onPlatform,
    retry: retry,
  );
}

/// Drop-in replacement for `flutter_test`'s `group` with Allure reporting.
void group(
  Object? description,
  dynamic Function() body, {
  Object? skip,
  int? retry,
}) {
  drop_in.group(
    description,
    body,
    skip: skip,
    retry: retry,
  );
}

/// Registers a setup callback as an Allure fixture.
void setUp(FutureOr<dynamic> Function() callback) {
  drop_in.setUp(callback);
}

/// Registers a teardown callback as an Allure fixture.
void tearDown(FutureOr<dynamic> Function() callback) {
  drop_in.tearDown(callback);
}

/// Registers a group-level setup callback as an Allure fixture.
void setUpAll(FutureOr<dynamic> Function() callback) {
  drop_in.setUpAll(callback);
}

/// Registers a group-level teardown callback as an Allure fixture.
void tearDownAll(FutureOr<dynamic> Function() callback) {
  drop_in.tearDownAll(callback);
}

/// Drop-in replacement for `flutter_test`'s `testWidgets` with Allure reporting.
void testWidgets(
  String description,
  ft.WidgetTesterCallback callback, {
  bool? skip,
  ft.Timeout? timeout,
  bool semanticsEnabled = true,
  ft.TestVariant<Object?> variant = const ft.DefaultTestVariant(),
  Object? tags,
  int? retry,
}) {
  drop_in.testWidgets(
    description,
    callback,
    skip: skip,
    timeout: timeout,
    semanticsEnabled: semanticsEnabled,
    variant: variant,
    tags: tags,
    retry: retry,
  );
}
