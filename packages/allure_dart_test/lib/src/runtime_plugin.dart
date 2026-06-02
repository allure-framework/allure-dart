import 'dart:async';

import 'package:allure_dart_commons/allure_dart_commons.dart';
import 'package:test/test.dart' as t;
// ignore: implementation_imports
import 'package:test_api/src/backend/invoker.dart' as internal_invoker;

import 'package_test_registry.dart';
import 'package_test_support.dart';

/// Resolves the Allure framework label for the active test framework.
typedef FrameworkLabelResolver = String Function();

/// Runtime plugin that records `package:test` execution as Allure results.
class AllureTestRuntimePlugin {
  /// Creates a runtime plugin.
  AllureTestRuntimePlugin({
    AllureLifecycle? lifecycle,
    FrameworkLabelResolver? frameworkLabelResolver,
  })  : _lifecycle = lifecycle ?? AllureLifecycle(),
        _frameworkLabelResolver =
            frameworkLabelResolver ?? _defaultFrameworkLabelResolver,
        _testPlan = parseTestPlan();

  static AllureTestRuntimePlugin? _installedPlugin;

  final AllureLifecycle _lifecycle;
  final FrameworkLabelResolver _frameworkLabelResolver;
  final TestPlanV1? _testPlan;
  final Expando<String> _uuidByTest = Expando<String>('allure_test_uuid');

  /// Lifecycle used by this plugin.
  AllureLifecycle get lifecycle => _lifecycle;

  /// Installs and returns the process-wide Allure runtime plugin.
  static AllureTestRuntimePlugin ensureInstalled({
    AllureLifecycle? lifecycle,
    FrameworkLabelResolver? frameworkLabelResolver,
  }) {
    final plugin = _installedPlugin ??
        AllureTestRuntimePlugin(
          lifecycle: lifecycle,
          frameworkLabelResolver: frameworkLabelResolver,
        );
    plugin.install();
    return plugin;
  }

  /// Installs lifecycle hooks into `package:test`.
  void install() {
    if (identical(_installedPlugin, this)) {
      return;
    }
    if (_installedPlugin != null) {
      setGlobalTestRuntime(
        MessageTestRuntime(
          sink: _installedPlugin!._lifecycle,
          contextResolver: _installedPlugin!.currentExecutionContext,
        ),
      );
      return;
    }

    _installedPlugin = this;
    setGlobalTestRuntime(
      MessageTestRuntime(
        sink: _lifecycle,
        contextResolver: currentExecutionContext,
      ),
    );

    t.setUp(() {
      _scheduleCurrentTestIfNeeded();
    });

    t.tearDown(() async {
      final resolved = _resolveCurrentTest();
      if (resolved == null) {
        return;
      }
      await _finishCurrentTest(resolved);
    });
  }

  /// Resolves the current Allure execution context for runtime APIs.
  AllureExecutionContext? currentExecutionContext() {
    final zoneContext = getZoneExecutionContext();
    if (zoneContext != null) {
      return zoneContext;
    }

    final resolved = _resolveCurrentTest();
    if (resolved == null) {
      return null;
    }
    final uuid = resolved.uuid;
    if (uuid == null || uuid.isEmpty) {
      return null;
    }
    return AllureExecutionContext(
      rootUuid: uuid,
      testUuid: uuid,
    );
  }

  /// Wraps a `setUp` callback so it is recorded as an Allure fixture.
  FutureOr<dynamic> Function() wrapSetUp(
    FutureOr<dynamic> Function() callback,
  ) {
    return () async {
      final context = currentExecutionContext();
      if (context == null) {
        return callback();
      }

      final scopeId = 'test:${context.testUuid}';
      _lifecycle.ensureScope(id: scopeId, expectedChildrenCount: 1);
      _lifecycle.lifecycleLinkTest(
          scopeId: scopeId, testUuid: context.testUuid);

      final fixtureUuid = _lifecycle.startFixture(
        scopeId: scopeId,
        before: true,
        name: 'setUp',
      );

      try {
        await runWithAllureContext(
          rootUuid: fixtureUuid,
          testUuid: context.testUuid,
          body: () async => await callback(),
        );
        await _lifecycle.stopFixture(
          fixtureUuid,
          status: AllureStatus.passed,
        );
      } catch (error, stackTrace) {
        await _lifecycle.stopFixture(
          fixtureUuid,
          status: getStatusFromError(error, stackTrace),
          error: error,
          stackTrace: stackTrace,
        );
        rethrow;
      }
    };
  }

  /// Wraps a `tearDown` callback so it is recorded as an Allure fixture.
  FutureOr<dynamic> Function() wrapTearDown(
    FutureOr<dynamic> Function() callback,
  ) {
    return () async {
      final context = currentExecutionContext();
      if (context == null) {
        return callback();
      }

      final scopeId = 'test:${context.testUuid}';
      _lifecycle.ensureScope(id: scopeId, expectedChildrenCount: 1);
      _lifecycle.lifecycleLinkTest(
          scopeId: scopeId, testUuid: context.testUuid);

      final fixtureUuid = _lifecycle.startFixture(
        scopeId: scopeId,
        before: false,
        name: 'tearDown',
      );

      try {
        await runWithAllureContext(
          rootUuid: fixtureUuid,
          testUuid: context.testUuid,
          body: () async => await callback(),
        );
        await _lifecycle.stopFixture(
          fixtureUuid,
          status: AllureStatus.passed,
        );
      } catch (error, stackTrace) {
        await _lifecycle.stopFixture(
          fixtureUuid,
          status: getStatusFromError(error, stackTrace),
          error: error,
          stackTrace: stackTrace,
        );
        rethrow;
      }
    };
  }

  /// Wraps a `setUpAll` callback so it is recorded as an Allure fixture.
  FutureOr<dynamic> Function() wrapSetUpAll(
    FutureOr<dynamic> Function() callback, {
    required List<String> groupPath,
    required String? packagePath,
  }) {
    return () async {
      final scopeId = buildPackageTestScopeId(packagePath, groupPath);
      _lifecycle.ensureScope(
        id: scopeId,
        name: groupPath.isEmpty ? null : groupPath.last,
        expectedChildrenCount: PackageTestScopeRegistry.instance
            .expectedChildrenForPath(groupPath, packagePath: packagePath),
      );

      final fixtureUuid = _lifecycle.startFixture(
        scopeId: scopeId,
        before: true,
        name: 'setUpAll',
      );

      try {
        await runWithAllureContext(
          rootUuid: fixtureUuid,
          testUuid: fixtureUuid,
          body: () async => await callback(),
        );
        await _lifecycle.stopFixture(
          fixtureUuid,
          status: AllureStatus.passed,
        );
      } catch (error, stackTrace) {
        await _lifecycle.stopFixture(
          fixtureUuid,
          status: getStatusFromError(error, stackTrace),
          error: error,
          stackTrace: stackTrace,
        );
        rethrow;
      }
    };
  }

  /// Wraps a `tearDownAll` callback so it is recorded as an Allure fixture.
  FutureOr<dynamic> Function() wrapTearDownAll(
    FutureOr<dynamic> Function() callback, {
    required List<String> groupPath,
    required String? packagePath,
  }) {
    return () async {
      final scopeId = buildPackageTestScopeId(packagePath, groupPath);
      _lifecycle.ensureScope(
        id: scopeId,
        name: groupPath.isEmpty ? null : groupPath.last,
        expectedChildrenCount: PackageTestScopeRegistry.instance
            .expectedChildrenForPath(groupPath, packagePath: packagePath),
      );

      final fixtureUuid = _lifecycle.startFixture(
        scopeId: scopeId,
        before: false,
        name: 'tearDownAll',
      );

      try {
        await runWithAllureContext(
          rootUuid: fixtureUuid,
          testUuid: fixtureUuid,
          body: () async => await callback(),
        );
        await _lifecycle.stopFixture(
          fixtureUuid,
          status: AllureStatus.passed,
        );
      } catch (error, stackTrace) {
        await _lifecycle.stopFixture(
          fixtureUuid,
          status: getStatusFromError(error, stackTrace),
          error: error,
          stackTrace: stackTrace,
        );
        rethrow;
      }

      await _lifecycle.writeScope(scopeId);
    };
  }

  void _scheduleCurrentTestIfNeeded() {
    final resolved = _resolveCurrentTest();
    if (resolved == null || resolved.uuid != null) {
      return;
    }

    final metadata = _buildTestMetadata(resolved.liveTest);
    final groupScopeIds = <String>[];
    final registry = PackageTestScopeRegistry.instance;
    final rootExpectedChildren = registry.expectedChildrenForPath(
      const <String>[],
      packagePath: metadata.packagePath,
    );
    if (rootExpectedChildren != null) {
      groupScopeIds.add(
        _lifecycle.ensureScope(
          id: buildPackageTestScopeId(
            metadata.packagePath,
            const <String>[],
          ),
          expectedChildrenCount: rootExpectedChildren,
        ),
      );
    }
    for (var index = 0; index < metadata.groupPath.length; index++) {
      final path = metadata.groupPath.take(index + 1).toList();
      final scopeId = buildPackageTestScopeId(metadata.packagePath, path);
      groupScopeIds.add(
        _lifecycle.ensureScope(
          id: scopeId,
          name: path.last,
          expectedChildrenCount: registry.expectedChildrenForPath(
            path,
            packagePath: metadata.packagePath,
          ),
        ),
      );
    }

    final fileScopeId = metadata.packagePath == null
        ? null
        : _lifecycle.ensureScope(
            id: 'file:${metadata.packagePath}',
            name: metadata.packagePath,
          );

    final scopeIds = <String>[
      if (fileScopeId != null) fileScopeId,
      ...groupScopeIds,
    ];
    final labels = <AllureLabel>[
      ...metadata.labels,
      if (metadata.packagePath != null) getPackageLabel(metadata.packagePath!),
      getFrameworkLabel(_frameworkLabelResolver()),
      getLanguageLabel(),
      getHostLabel(),
      getThreadLabel(),
      AllureLabel(name: 'testMethod', value: metadata.name),
      AllureLabel(
        name: 'testClass',
        value: metadata.testClass,
      ),
    ];

    if (_testPlan != null &&
        !includedInTestPlan(
          _testPlan,
          id: metadata.externalId,
          fullName: metadata.fullName,
          nativeSelector: metadata.nativeSelector,
          tags: metadata.rawTags,
        )) {
      addSkipLabel(labels);
    }

    final testUuid = _lifecycle.startTest(
      name: metadata.name,
      fullName: metadata.fullName,
      testCaseName: metadata.testCaseName,
      titlePath: metadata.titlePath,
      labels: labels,
      links: metadata.links,
      parameters: metadata.parameters,
      scopeIds: scopeIds,
      defaultSuites: metadata.groupPath,
      stage: metadata.skipped ? AllureStage.pending : AllureStage.running,
    );

    _uuidByTest[resolved.test] = testUuid;
    resolved.uuid = testUuid;
  }

  Future<void> _finishCurrentTest(_ResolvedTest resolved) async {
    final uuid = resolved.uuid;
    if (uuid == null) {
      return;
    }

    final failure = _extractFailure(resolved.liveTest);
    await _lifecycle.stopTest(
      uuid,
      status: _resolveStatus(resolved.liveTest),
      error: failure?.error,
      stackTrace: failure?.stackTrace,
    );
    await _lifecycle.writeTest(uuid);
    _uuidByTest[resolved.test] = '';
  }

  _ResolvedTest? _resolveCurrentTest() {
    final dynamic invoker = internal_invoker.Invoker.current;
    final dynamic liveTest = _maybe<dynamic>(() => invoker?.liveTest);
    if (liveTest == null) {
      return null;
    }

    final dynamic descriptor = _maybe<dynamic>(() => liveTest.test) ?? liveTest;
    final isScaffoldAll = _maybe<bool>(() => descriptor.isScaffoldAll) ?? false;
    if (isScaffoldAll) {
      return null;
    }

    return _ResolvedTest(
      liveTest: liveTest,
      test: descriptor is Object ? descriptor : liveTest,
      uuid: descriptor is Object ? _uuidByTest[descriptor] : null,
    );
  }

  PackageTestMetadata _buildTestMetadata(dynamic liveTest) {
    final rawName = liveTest.individualName.toString().isEmpty
        ? liveTest.test.name.toString()
        : liveTest.individualName.toString();
    final rawTags =
        ((_maybe<dynamic>(() => liveTest.test.metadata?.tags) as Iterable?) ??
                const <String>[])
            .whereType<String>()
            .toList();
    final location = _maybe<dynamic>(() => liveTest.test.location);
    final packagePath = extractPackageTestPath(liveTest, location);
    final groupPath = extractPackageTestGroupPath(liveTest);
    final retryCount = (Zone.current[#runCount] as int?) ?? 1;
    final skipped = _maybe<bool>(() => liveTest.test.metadata?.skip) ?? false;
    final metadata = buildPackageTestMetadata(
      rawName: rawName,
      rawTags: rawTags,
      groupPath: groupPath,
      packagePath: packagePath,
      retryCount: retryCount,
      skipped: skipped,
    );
    return mergePackageTestMetadata(
      metadata,
      PackageTestScopeRegistry.instance.metadataForFullName(metadata.fullName),
    );
  }

  AllureStatus _resolveStatus(dynamic liveTest) {
    final dynamic state = _maybe<dynamic>(() => liveTest.state);
    final dynamic result = _maybe<dynamic>(() => state?.result);
    final dynamic status = _maybe<dynamic>(() => state?.status);

    final value = '${result ?? status}'.toLowerCase();
    if (value.contains('skip')) {
      return AllureStatus.skipped;
    }
    if (value.contains('failure')) {
      return AllureStatus.failed;
    }
    if (value.contains('error')) {
      return AllureStatus.broken;
    }
    return AllureStatus.passed;
  }

  _FailureDetails? _extractFailure(dynamic liveTest) {
    final errors = _extractErrors(liveTest);
    if (errors.isEmpty) {
      return null;
    }
    if (errors.length == 1) {
      final first = errors.first;
      final error = _maybe<dynamic>(() => first.error) ?? first;
      return _FailureDetails(
        error: error,
        stackTrace: _extractStackTrace(first) ?? _extractStackTrace(error),
      );
    }

    final traces = <String>[];
    for (final error in errors) {
      final trace = _extractStackTrace(error);
      if (trace != null) {
        traces.add(trace.toString());
      }
    }
    return _FailureDetails(
      error: StateError('Expected 0 failures, but got ${errors.length}'),
      stackTrace:
          traces.isEmpty ? null : StackTrace.fromString(traces.join('\n\n')),
    );
  }

  List<dynamic> _extractErrors(dynamic liveTest) {
    final errors = _maybe<dynamic>(() => liveTest.errors);
    if (errors is List<dynamic>) {
      return errors;
    }
    return const <dynamic>[];
  }

  StackTrace? _extractStackTrace(dynamic value) {
    final stackTrace = _maybe<dynamic>(() => value.stackTrace);
    if (stackTrace == null) {
      return null;
    }
    return StackTrace.fromString(stackTrace.toString());
  }

  T? _maybe<T>(T Function() getter) {
    try {
      return getter();
    } catch (_) {
      return null;
    }
  }
}

/// Installs the Allure runtime plugin for `package:test`.
void installAllure({AllureLifecycle? lifecycle}) {
  AllureTestRuntimePlugin.ensureInstalled(lifecycle: lifecycle);
}

String _defaultFrameworkLabelResolver() => 'dart-test';

class _ResolvedTest {
  _ResolvedTest({
    required this.liveTest,
    required this.test,
    this.uuid,
  });

  final dynamic liveTest;
  final Object test;
  String? uuid;
}

class _FailureDetails {
  const _FailureDetails({
    required this.error,
    required this.stackTrace,
  });

  final Object error;
  final StackTrace? stackTrace;
}
