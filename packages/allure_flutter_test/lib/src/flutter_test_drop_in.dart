import 'dart:async';

import 'package:allure_dart_commons/allure_dart_commons.dart';
import 'package:allure_dart_test/adapter_support.dart';
import 'package:allure_dart_test/allure_dart_test.dart'
    show AllureTestRuntimePlugin;
import 'package:flutter_test/flutter_test.dart' as ft;

import 'flutter_install.dart';

const List<String> _ignoredLibrarySuffixes = <String>[
  '/lib/src/flutter_test_drop_in.dart',
];

AllureTestRuntimePlugin _ensureAllureInstalled() {
  installAllure();
  return AllureTestRuntimePlugin.ensureInstalled();
}

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
  _ensureAllureInstalled();
  final packagePath = resolvePackageTestPathFromDeclaration(
    stackTrace: StackTrace.current,
    ignoredLibrarySuffixes: _ignoredLibrarySuffixes,
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

  ft.test(
    description ?? '',
    body,
    testOn: testOn,
    timeout: timeout,
    skip: effectiveSkip,
    tags: tags,
    onPlatform: onPlatform,
    retry: retry,
  );
}

void group(
  Object? description,
  dynamic Function() body, {
  Object? skip,
  int? retry,
}) {
  _ensureAllureInstalled();
  final name = description?.toString() ?? '';
  final packagePath = resolvePackageTestPathFromDeclaration(
    stackTrace: StackTrace.current,
    ignoredLibrarySuffixes: _ignoredLibrarySuffixes,
  );
  PackageTestScopeRegistry.instance.pushGroup(
    name,
    packagePath: packagePath,
  );
  ft.group(
    description ?? '',
    () {
      try {
        body();
      } finally {
        PackageTestScopeRegistry.instance.popGroup();
      }
    },
    skip: skip,
    retry: retry,
  );
}

void setUp(FutureOr<dynamic> Function() callback) {
  final plugin = _ensureAllureInstalled();
  ft.setUp(plugin.wrapSetUp(callback));
}

void tearDown(FutureOr<dynamic> Function() callback) {
  final plugin = _ensureAllureInstalled();
  ft.tearDown(plugin.wrapTearDown(callback));
}

void setUpAll(FutureOr<dynamic> Function() callback) {
  final plugin = _ensureAllureInstalled();
  final groupPath = PackageTestScopeRegistry.instance.currentPath;
  final packagePath = PackageTestScopeRegistry.instance.currentPackagePath ??
      resolvePackageTestPathFromDeclaration(
        stackTrace: StackTrace.current,
        ignoredLibrarySuffixes: _ignoredLibrarySuffixes,
      );
  ft.setUpAll(
    plugin.wrapSetUpAll(
      callback,
      groupPath: groupPath,
      packagePath: packagePath,
    ),
  );
}

void tearDownAll(FutureOr<dynamic> Function() callback) {
  final plugin = _ensureAllureInstalled();
  final groupPath = PackageTestScopeRegistry.instance.currentPath;
  final packagePath = PackageTestScopeRegistry.instance.currentPackagePath ??
      resolvePackageTestPathFromDeclaration(
        stackTrace: StackTrace.current,
        ignoredLibrarySuffixes: _ignoredLibrarySuffixes,
      );
  ft.tearDownAll(
    plugin.wrapTearDownAll(
      callback,
      groupPath: groupPath,
      packagePath: packagePath,
    ),
  );
}

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
  _ensureAllureInstalled();
  final packagePath = resolvePackageTestPathFromDeclaration(
    stackTrace: StackTrace.current,
    ignoredLibrarySuffixes: _ignoredLibrarySuffixes,
  );
  final groupPath = PackageTestScopeRegistry.instance.currentPath;
  final testPlan = parseTestPlan();
  final variantValues = variant.values.toList(growable: false);

  for (final value in variantValues) {
    PackageTestScopeRegistry.instance.registerTest(packagePath: packagePath);
    final variationDescription = variant.describeValue(value);
    final combinedDescription = variationDescription.isEmpty
        ? description
        : '$description (variant: $variationDescription)';
    final declaredMetadata = buildPackageTestMetadata(
      rawName: combinedDescription,
      rawTags: normalizePackageTestTags(tags),
      groupPath: groupPath,
      packagePath: packagePath,
      skipped: skip == true,
      testCaseName: description,
      additionalParameters: <AllureParameter>[
        if (variationDescription.isNotEmpty)
          AllureParameter(name: 'variant', value: variationDescription),
      ],
    );
    PackageTestScopeRegistry.instance.registerMetadata(declaredMetadata);

    var effectiveSkip = skip;
    if (testPlan != null &&
        !includedInTestPlan(
          testPlan,
          id: declaredMetadata.externalId,
          fullName: declaredMetadata.fullName,
          nativeSelector: declaredMetadata.nativeSelector,
          tags: declaredMetadata.rawTags,
        ) &&
        skip != true) {
      effectiveSkip = true;
    }

    ft.testWidgets(
      description,
      callback,
      skip: effectiveSkip,
      timeout: timeout,
      semanticsEnabled: semanticsEnabled,
      variant: _SingleValueVariant<Object?>(delegate: variant, value: value),
      tags: tags,
      retry: retry,
    );
  }
}

class _SingleValueVariant<T extends Object?> extends ft.TestVariant<T> {
  const _SingleValueVariant({
    required ft.TestVariant<T> delegate,
    required T value,
  })  : _delegate = delegate,
        _value = value;

  final ft.TestVariant<T> _delegate;
  final T _value;

  @override
  Iterable<T> get values => <T>[_value];

  @override
  String describeValue(T value) => _delegate.describeValue(value);

  @override
  Future<Object?> setUp(T value) => _delegate.setUp(value);

  @override
  Future<void> tearDown(T value, covariant Object? memento) {
    return _delegate.tearDown(value, memento);
  }
}
