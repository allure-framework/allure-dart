import 'dart:async';

import 'package:allure_dart_commons/allure_dart_commons.dart';
import 'package:allure_dart_test/adapter_support.dart';
import 'package:allure_dart_test/allure_dart_test.dart'
    show AllureTestRuntimePlugin;
import 'package:flutter_test/flutter_test.dart' as ft;
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart'
    show LeakTesting;

import 'flutter_install.dart';

const List<String> _ignoredLibrarySuffixes = <String>[
  '/lib/src/flutter_test_drop_in.dart',
  // `integration_test.dart` re-declares wrapper functions that call into
  // this file, so it sits on the stack above `flutter_test_drop_in.dart`
  // for host-run integration tests and must also be ignored when resolving
  // the user's test file path.
  '/lib/integration_test.dart',
];

AllureTestRuntimePlugin _ensureAllureInstalled() {
  installAllure();
  return AllureTestRuntimePlugin.ensureInstalled();
}

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
  _ensureAllureInstalled();
  final prepared = preparePackageTestDeclaration(
    description: description,
    skip: skip,
    tags: tags,
    stackTrace: StackTrace.current,
    ignoredLibrarySuffixes: _ignoredLibrarySuffixes,
  );

  dynamic Function() effectiveBody = body;
  if (prepared.shouldRuntimeSkip) {
    effectiveBody = () => ft.markTestSkipped(prepared.runtimeSkipReason);
  }

  ft.test(
    description ?? '',
    effectiveBody,
    testOn: testOn,
    timeout: timeout,
    skip: prepared.declarationSkip,
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
  _ensureAllureInstalled();
  pushDeclaredPackageTestGroup(
    description: description,
    skip: skip,
    stackTrace: StackTrace.current,
    ignoredLibrarySuffixes: _ignoredLibrarySuffixes,
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
    retry: retry,
  );
}

/// Registers a setup callback as an Allure fixture.
void setUp(FutureOr<dynamic> Function() callback) {
  final plugin = _ensureAllureInstalled();
  ft.setUp(plugin.wrapSetUp(callback));
}

/// Registers a teardown callback as an Allure fixture.
void tearDown(FutureOr<dynamic> Function() callback) {
  final plugin = _ensureAllureInstalled();
  ft.tearDown(plugin.wrapTearDown(callback));
}

/// Registers a group-level setup callback as an Allure fixture.
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

/// Registers a group-level teardown callback as an Allure fixture.
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
  LeakTesting? experimentalLeakTesting,
}) {
  _ensureAllureInstalled();
  // Resolve path once for all variants — stack walk is the same each time.
  final packagePath = resolvePackageTestPathFromDeclaration(
    stackTrace: StackTrace.current,
    ignoredLibrarySuffixes: _ignoredLibrarySuffixes,
  );
  final variantValues = variant.values.toList(growable: false);

  for (final value in variantValues) {
    final variationDescription = variant.describeValue(value);
    // Must match flutter_test's internal variant naming so declared metadata
    // merges with the runtime LiveTest name.
    final combinedDescription = variationDescription.isEmpty
        ? description
        : '$description (variant: $variationDescription)';
    final prepared = preparePackageTestDeclaration(
      description: description,
      skip: skip,
      tags: tags,
      packagePath: packagePath,
      rawName: combinedDescription,
      testCaseName: description,
      additionalParameters: <AllureParameter>[
        if (variationDescription.isNotEmpty)
          AllureParameter(name: 'variant', value: variationDescription),
      ],
    );

    ft.WidgetTesterCallback effectiveCallback = callback;
    if (prepared.shouldRuntimeSkip) {
      effectiveCallback = (tester) async {
        ft.markTestSkipped(prepared.runtimeSkipReason);
      };
    }

    ft.testWidgets(
      description,
      effectiveCallback,
      skip: prepared.declarationSkipFlag,
      timeout: timeout,
      semanticsEnabled: semanticsEnabled,
      variant: _SingleValueVariant<Object?>(delegate: variant, value: value),
      tags: tags,
      retry: retry,
      experimentalLeakTesting: experimentalLeakTesting,
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
