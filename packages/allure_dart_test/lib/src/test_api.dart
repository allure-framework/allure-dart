import 'dart:async';

import 'package:allure_dart_commons/allure_dart_commons.dart';
import 'package:test/test.dart' as t;
// ignore: implementation_imports
import 'package:test_api/src/backend/invoker.dart' as internal_invoker;

import 'package_test_support.dart';

/// Global lifecycle used by the `allureTest` convenience API.
final AllureLifecycle globalAllureLifecycle = AllureLifecycle();
final TestRuntime _globalAllureRuntime = MessageTestRuntime(
  sink: globalAllureLifecycle,
  contextResolver: getZoneExecutionContext,
);

/// Body callback for [allureTest].
typedef AllureTestBody = FutureOr<void> Function(AllureTestContext context);

/// Allure helpers scoped to a single `allureTest` body.
class AllureTestContext {
  /// Creates a test context for [testUuid].
  AllureTestContext(this._lifecycle, this.testUuid);

  final AllureLifecycle _lifecycle;

  /// UUID of the active Allure test result.
  final String testUuid;

  /// Runs [body] inside an Allure step.
  Future<T> step<T>(String name, FutureOr<T> Function() body) {
    return _lifecycle.runStep(testUuid, name, body);
  }

  /// Adds a binary attachment to the current test.
  Future<void> attachment({
    required String name,
    required String type,
    required List<int> content,
    String? extension,
    bool wrapInStep = true,
  }) {
    return _lifecycle.addAttachment(
      testUuid: testUuid,
      name: name,
      type: type,
      content: content,
      extension: extension,
      wrapInStep: wrapInStep,
    );
  }

  /// Adds a text attachment to the current test.
  Future<void> textAttachment({
    required String name,
    required String content,
    String type = 'text/plain',
    String? extension,
    bool wrapInStep = true,
  }) {
    return _lifecycle.addTextAttachment(
      testUuid: testUuid,
      name: name,
      type: type,
      content: content,
      extension: extension,
      wrapInStep: wrapInStep,
    );
  }

  /// Adds an attachment from a byte stream to the current test.
  Future<void> streamAttachment({
    required String name,
    required Stream<List<int>> content,
    required String type,
    String? extension,
    bool wrapInStep = true,
  }) {
    return _lifecycle.addAttachmentStreamToRoot(
      testUuid,
      name: name,
      content: content,
      contentType: type,
      fileExtension: extension,
      wrapInStep: wrapInStep,
    );
  }

  /// Adds an attachment through a prepared temporary file.
  Future<void> preparedAttachment({
    required String name,
    required String type,
    String? extension,
    required Future<void> Function(AllurePreparedAttachment attachment) write,
    bool wrapInStep = true,
  }) {
    return _lifecycle.addPreparedAttachmentToRoot(
      testUuid,
      name: name,
      contentType: type,
      fileExtension: extension,
      write: write,
      wrapInStep: wrapInStep,
    );
  }

  /// Adds a label to the current test.
  Future<void> label(String name, String value) =>
      _lifecycle.handleRuntimeMessage(
        RuntimeMessage(
          type: 'metadata',
          data: <String, Object?>{
            'labels': <Map<String, String>>[
              AllureLabel(name: name, value: value).toJson(),
            ],
          },
        ),
        rootUuid: testUuid,
      );

  /// Adds a parameter to the current test.
  Future<void> parameter(
    String name,
    Object? value, {
    bool? excluded,
    AllureParameterMode? mode,
  }) {
    return _lifecycle.handleRuntimeMessage(
      RuntimeMessage(
        type: 'metadata',
        data: <String, Object?>{
          'parameters': <Map<String, Object?>>[
            AllureParameter(
              name: name,
              value: serializeValue(value),
              excluded: excluded,
              mode: mode,
            ).toJson(),
          ],
        },
      ),
      rootUuid: testUuid,
    );
  }

  /// Sets the test case name for the current test.
  Future<void> testCaseName(String value) {
    return _lifecycle.handleRuntimeMessage(
      RuntimeMessage(
        type: 'metadata',
        data: <String, Object?>{'testCaseName': value},
      ),
      rootUuid: testUuid,
    );
  }

  /// Adds status details to the current test.
  Future<void> statusDetails({
    String? message,
    String? trace,
    bool? known,
    bool? muted,
    bool? flaky,
    String? actual,
    String? expected,
  }) {
    return _lifecycle.handleRuntimeMessage(
      RuntimeMessage(
        type: 'metadata',
        data: <String, Object?>{
          'statusDetails': AllureStatusDetails(
            message: message,
            trace: trace,
            known: known,
            muted: muted,
            flaky: flaky,
            actual: actual,
            expected: expected,
          ).toJson(),
        },
      ),
      rootUuid: testUuid,
    );
  }
}

/// Defines a `package:test` test with an [AllureTestContext].
void allureTest(
  String description,
  AllureTestBody body, {
  t.Timeout? timeout,
  dynamic skip,
  List<AllureLabel> labels = const <AllureLabel>[],
  List<AllureParameter> parameters = const <AllureParameter>[],
  List<AllureLink> links = const <AllureLink>[],
}) {
  t.test(
    description,
    () async {
      setGlobalTestRuntime(_globalAllureRuntime);

      final metadata = _buildCurrentTestMetadata(
        fallbackName: description,
        skipped: skip != null && skip != false,
      );
      final testPlan = parseTestPlan();
      final excludedByTestPlan = testPlan != null &&
          !includedInTestPlan(
            testPlan,
            id: metadata.externalId,
            fullName: metadata.fullName,
            nativeSelector: metadata.nativeSelector,
            tags: metadata.rawTags,
          );
      final resultLabels = <AllureLabel>[
        ...metadata.labels,
        if (metadata.packagePath != null)
          getPackageLabel(metadata.packagePath!),
        getFrameworkLabel('dart-test'),
        getLanguageLabel(),
        getHostLabel(),
        getThreadLabel(),
        AllureLabel(name: 'testMethod', value: metadata.name),
        AllureLabel(name: 'testClass', value: metadata.testClass),
        ...labels,
      ];
      if (excludedByTestPlan) {
        addSkipLabel(resultLabels);
      }
      final testUuid = globalAllureLifecycle.startTest(
        name: metadata.name,
        fullName: metadata.fullName,
        testCaseName: metadata.testCaseName,
        titlePath: metadata.titlePath,
        labels: resultLabels,
        links: <AllureLink>[
          ...metadata.links,
          ...links,
        ],
        parameters: <AllureParameter>[
          ...metadata.parameters,
          ...parameters,
        ],
        defaultSuites: metadata.groupPath,
        stage: metadata.skipped || excludedByTestPlan
            ? AllureStage.pending
            : AllureStage.running,
      );

      final context = AllureTestContext(globalAllureLifecycle, testUuid);
      Object? caughtError;
      StackTrace? caughtStackTrace;

      try {
        if (excludedByTestPlan) {
          t.markTestSkipped('Excluded by Allure test plan');
          await globalAllureLifecycle.stopTest(
            testUuid,
            status: AllureStatus.skipped,
            statusDetails: const AllureStatusDetails(
              message: 'Excluded by Allure test plan',
            ),
          );
        } else {
          await runWithAllureContext(
            rootUuid: testUuid,
            testUuid: testUuid,
            body: () async => await body(context),
          );
          await globalAllureLifecycle.stopTest(
            testUuid,
            status: AllureStatus.passed,
          );
        }
      } catch (error, stackTrace) {
        caughtError = error;
        caughtStackTrace = stackTrace;
        await globalAllureLifecycle.stopTest(
          testUuid,
          status: getStatusFromError(error, stackTrace),
          error: error,
          stackTrace: stackTrace,
        );
      }

      await globalAllureLifecycle.writeTest(testUuid);
      if (caughtError != null) {
        Error.throwWithStackTrace(caughtError, caughtStackTrace!);
      }
    },
    timeout: timeout,
    skip: skip,
  );
}

PackageTestMetadata _buildCurrentTestMetadata({
  required String fallbackName,
  required bool skipped,
}) {
  final liveTest =
      _maybe<dynamic>(() => internal_invoker.Invoker.current?.liveTest);
  if (liveTest == null) {
    return buildPackageTestMetadata(
      rawName: fallbackName,
      skipped: skipped,
    );
  }

  final rawName = liveTest.individualName.toString().isEmpty
      ? liveTest.test.name.toString()
      : liveTest.individualName.toString();
  final rawTags =
      ((_maybe<dynamic>(() => liveTest.test.metadata?.tags) as Iterable?) ??
              const <String>[])
          .whereType<String>()
          .toList();
  final location = _maybe<dynamic>(() => liveTest.test.location);
  return buildPackageTestMetadata(
    rawName: rawName,
    rawTags: rawTags,
    groupPath: extractPackageTestGroupPath(liveTest),
    packagePath: extractPackageTestPath(liveTest, location),
    retryCount: (Zone.current[#runCount] as int?) ?? 1,
    skipped: _maybe<bool>(() => liveTest.test.metadata?.skip) ?? skipped,
  );
}

T? _maybe<T>(T Function() getter) {
  try {
    return getter();
  } catch (_) {
    return null;
  }
}
