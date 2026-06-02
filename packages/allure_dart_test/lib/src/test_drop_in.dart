// ignore_for_file: deprecated_member_use, invalid_use_of_do_not_submit_member

import 'dart:async';

import 'package:test/test.dart' as t;

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
  final packagePath = resolvePackageTestPathFromDeclaration(
    locationUri: location?.uri,
    stackTrace: StackTrace.current,
  );
  final groupPath = PackageTestScopeRegistry.instance.currentPath;
  PackageTestScopeRegistry.instance.registerTest(packagePath: packagePath);
  final declaredMetadata = buildPackageTestMetadata(
    rawName: description?.toString() ?? '',
    rawTags: normalizePackageTestTags(tags),
    groupPath: groupPath,
    packagePath: packagePath,
    skipped: skip != null && skip != false,
  );
  PackageTestScopeRegistry.instance.registerMetadata(declaredMetadata);
  Object? effectiveSkip = skip;
  final testPlan = parseTestPlan();
  if (testPlan != null &&
      !includedInTestPlan(
        testPlan,
        id: declaredMetadata.externalId,
        fullName: declaredMetadata.fullName,
        nativeSelector: declaredMetadata.nativeSelector,
        tags: declaredMetadata.rawTags,
      ) &&
      (skip == null || skip == false)) {
    effectiveSkip = 'Excluded by Allure test plan';
  }
  t.test(
    description,
    body,
    testOn: testOn,
    timeout: timeout,
    skip: effectiveSkip,
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
  final name = description?.toString() ?? '';
  final packagePath = resolvePackageTestPathFromDeclaration(
    locationUri: location?.uri,
    stackTrace: StackTrace.current,
  );
  PackageTestScopeRegistry.instance.pushGroup(
    name,
    packagePath: packagePath,
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
    skip: skip,
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
