// ignore_for_file: deprecated_member_use, invalid_use_of_do_not_submit_member

import 'dart:async';

import 'package:test/test.dart' as t;

import 'package_test_declaration.dart';
import 'package_test_registry.dart';
import 'package_test_support.dart';
import 'runtime_plugin.dart';

AllureTestRuntimePlugin _ensureAllureInstalled() {
  return AllureTestRuntimePlugin.ensureInstalled();
}

/// Drop-in replacement for `package:test`'s `test` with Allure reporting.
void test(
  Object? description,
  FutureOr<dynamic> Function() body, {
  String? testOn,
  t.Timeout? timeout,
  Object? skip,
  Object? tags,
  Map<String, dynamic>? onPlatform,
  int? retry,
  t.TestLocation? location,
  @Deprecated('Debug only') bool solo = false,
}) {
  _ensureAllureInstalled();
  final prepared = preparePackageTestDeclaration(
    description: description,
    skip: skip,
    tags: tags,
    locationUri: location?.uri,
    stackTrace: StackTrace.current,
  );

  FutureOr<dynamic> Function() effectiveBody = body;
  if (prepared.shouldRuntimeSkip) {
    effectiveBody = () => t.markTestSkipped(prepared.runtimeSkipReason);
  }

  t.test(
    description,
    effectiveBody,
    testOn: testOn,
    timeout: timeout,
    skip: prepared.declarationSkip,
    tags: tags,
    onPlatform: onPlatform,
    retry: retry,
    location: location,
    solo: solo,
  );
}

/// Drop-in replacement for `package:test`'s `group` with Allure reporting.
void group(
  Object? description,
  dynamic Function() body, {
  String? testOn,
  t.Timeout? timeout,
  Object? skip,
  Object? tags,
  Map<String, dynamic>? onPlatform,
  int? retry,
  t.TestLocation? location,
  @Deprecated('Debug only') bool solo = false,
}) {
  _ensureAllureInstalled();
  pushDeclaredPackageTestGroup(
    description: description,
    skip: skip,
    locationUri: location?.uri,
    stackTrace: StackTrace.current,
  );
  t.group(
    description,
    () {
      try {
        body();
      } finally {
        PackageTestScopeRegistry.instance.popGroup();
      }
    },
    testOn: testOn,
    timeout: timeout,
    tags: tags,
    onPlatform: onPlatform,
    retry: retry,
    location: location,
    solo: solo,
  );
}

/// Registers a setup callback as an Allure fixture.
void setUp(FutureOr<dynamic> Function() callback) {
  final plugin = _ensureAllureInstalled();
  t.setUp(plugin.wrapSetUp(callback));
}

/// Registers a teardown callback as an Allure fixture.
void tearDown(FutureOr<dynamic> Function() callback) {
  final plugin = _ensureAllureInstalled();
  t.tearDown(plugin.wrapTearDown(callback));
}

/// Registers a group-level setup callback as an Allure fixture.
void setUpAll(
  FutureOr<dynamic> Function() callback, {
  t.TestLocation? location,
}) {
  final plugin = _ensureAllureInstalled();
  final groupPath = PackageTestScopeRegistry.instance.currentPath;
  final packagePath = PackageTestScopeRegistry.instance.currentPackagePath ??
      resolvePackageTestPathFromDeclaration(
        locationUri: location?.uri,
        stackTrace: StackTrace.current,
      );
  t.setUpAll(
    plugin.wrapSetUpAll(
      callback,
      groupPath: groupPath,
      packagePath: packagePath,
    ),
    location: location,
  );
}

/// Registers a group-level teardown callback as an Allure fixture.
void tearDownAll(
  FutureOr<dynamic> Function() callback, {
  t.TestLocation? location,
}) {
  final plugin = _ensureAllureInstalled();
  final groupPath = PackageTestScopeRegistry.instance.currentPath;
  final packagePath = PackageTestScopeRegistry.instance.currentPackagePath ??
      resolvePackageTestPathFromDeclaration(
        locationUri: location?.uri,
        stackTrace: StackTrace.current,
      );
  t.tearDownAll(
    plugin.wrapTearDownAll(
      callback,
      groupPath: groupPath,
      packagePath: packagePath,
    ),
    location: location,
  );
}
