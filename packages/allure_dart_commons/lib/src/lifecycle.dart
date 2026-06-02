import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import 'model.dart';
import 'runtime.dart';
import 'utils.dart';
import 'writer.dart';

/// Listener hooks for observing Allure lifecycle events.
class AllureLifecycleListener {
  /// Creates a lifecycle listener with no-op hooks.
  const AllureLifecycleListener();

  /// Called before a test result is stored in the lifecycle.
  void beforeTestStart(AllureTestResult result) {}

  /// Called after a test result is stored in the lifecycle.
  void afterTestStart(AllureTestResult result) {}

  /// Called before a test result is stopped.
  void beforeTestStop(AllureTestResult result) {}

  /// Called after a test result is stopped.
  void afterTestStop(AllureTestResult result) {}

  /// Called before a test result is written.
  void beforeTestWrite(AllureTestResult result) {}

  /// Called after a test result is written.
  void afterTestWrite(AllureTestResult result) {}

  /// Called before a step result is stopped.
  void beforeStepStop(AllureStepResult result) {}

  /// Called after a step result is stopped.
  void afterStepStop(AllureStepResult result) {}

  /// Called before a container result is written.
  void beforeContainerWrite(AllureTestResultContainer container) {}

  /// Called after a container result is written.
  void afterContainerWrite(AllureTestResultContainer container) {}

  /// Called when an attachment is added to a test, fixture, or step.
  void onAttachment(String rootUuid, AllureAttachment attachment) {}

  /// Called when a run-level attachment is written.
  void onGlobalAttachment(AllureGlobalAttachment attachment) {}

  /// Called when a run-level error is written.
  void onGlobalError(AllureGlobalError error) {}
}

/// Mutable Allure lifecycle used to build and write result files.
class AllureLifecycle implements AllureRuntimeMessageSink {
  /// Creates an Allure lifecycle with optional writer and run metadata.
  AllureLifecycle({
    AllureResultsWriter? writer,
    Uuid? uuid,
    Map<String, String>? linkUrlTemplates,
    Map<String, String>? linkNameTemplates,
    List<AllureLabel>? globalLabels,
    AllureEnvironmentInfo? environmentInfo,
    List<AllureCategory>? categories,
    AllureExecutorInfo? executorInfo,
    List<AllureLifecycleListener>? listeners,
  })  : _writer = writer ?? AllureResultsWriter(uuid: uuid),
        _uuid = uuid ?? const Uuid(),
        _linkUrlTemplates = linkUrlTemplates ?? const <String, String>{},
        _linkNameTemplates = linkNameTemplates ?? const <String, String>{},
        _globalLabels = globalLabels ?? const <AllureLabel>[],
        _environmentInfo = environmentInfo ?? const <String, String?>{},
        _categories = categories ?? const <AllureCategory>[],
        _executorInfo = executorInfo,
        _listeners = listeners ?? const <AllureLifecycleListener>[];

  final AllureResultsWriter _writer;
  final Uuid _uuid;
  final Map<String, String> _linkUrlTemplates;
  final Map<String, String> _linkNameTemplates;
  final List<AllureLabel> _globalLabels;
  final AllureEnvironmentInfo _environmentInfo;
  final List<AllureCategory> _categories;
  final AllureExecutorInfo? _executorInfo;
  final List<AllureLifecycleListener> _listeners;

  final Map<String, _TestState> _tests = <String, _TestState>{};
  final Map<String, _ScopeState> _scopes = <String, _ScopeState>{};
  final Map<String, _FixtureState> _fixtures = <String, _FixtureState>{};
  final Map<String, List<AllureStepResult>> _stepStacks =
      <String, List<AllureStepResult>>{};

  bool _runMetadataWritten = false;

  /// Ensures that a result container scope exists and returns its id.
  String ensureScope({
    required String id,
    String? name,
    int? expectedChildrenCount,
  }) {
    final scope = _scopes.putIfAbsent(
      id,
      () => _ScopeState(id: id, name: name),
    );
    if (name != null && scope.name == null) {
      scope.name = name;
    }
    if (expectedChildrenCount != null) {
      scope.expectedChildrenCount = expectedChildrenCount;
    }
    return scope.id;
  }

  /// Sets the expected number of child tests for a scope.
  void setScopeExpectedChildren(String scopeId, int expectedChildrenCount) {
    final scope = _scopes.putIfAbsent(
      scopeId,
      () => _ScopeState(id: scopeId),
    );
    scope.expectedChildrenCount = expectedChildrenCount;
  }

  /// Links an existing test result to a lifecycle scope.
  void lifecycleLinkTest({
    required String scopeId,
    required String testUuid,
  }) {
    final scope = _scopes.putIfAbsent(
      scopeId,
      () => _ScopeState(id: scopeId),
    );
    if (!scope.children.contains(testUuid)) {
      scope.children.add(testUuid);
    }
    final test = _tests[testUuid];
    if (test != null && !test.scopeIds.contains(scopeId)) {
      test.scopeIds.add(scopeId);
    }
  }

  /// Starts a test result and returns its generated UUID.
  String startTest({
    required String name,
    String? fullName,
    String? testCaseId,
    String? testCaseName,
    String? historyId,
    List<String>? titlePath,
    List<AllureLabel>? labels,
    List<AllureLink>? links,
    List<AllureParameter>? parameters,
    AllureStatusDetails statusDetails = const AllureStatusDetails(),
    List<String> scopeIds = const <String>[],
    List<String> defaultSuites = const <String>[],
    int? start,
    AllureStage stage = AllureStage.running,
  }) {
    final uuid = _uuid.v4();
    final result = AllureTestResult(
      uuid: uuid,
      historyId: historyId,
      fullName: fullName ?? name,
      testCaseId: testCaseId,
      testCaseName: testCaseName ?? name,
      titlePath: titlePath,
      name: name,
      statusDetails: statusDetails,
      labels: <AllureLabel>[...?labels],
      links: <AllureLink>[...?links],
      parameters: <AllureParameter>[...?parameters],
      start: start ?? currentTimestamp(),
      stage: stage,
    );
    _notify('beforeTestStart', (listener) => listener.beforeTestStart(result));
    final state = _TestState(
      result: result,
      scopeIds: <String>[...scopeIds],
      defaultSuites: <String>[...defaultSuites],
    );
    _tests[uuid] = state;
    _stepStacks[uuid] = <AllureStepResult>[];

    for (final scopeId in scopeIds) {
      final scope = _scopes.putIfAbsent(
        scopeId,
        () => _ScopeState(id: scopeId),
      );
      scope.children.add(uuid);
    }

    _notify('afterTestStart', (listener) => listener.afterTestStart(result));
    return uuid;
  }

  /// Schedules a test case using the same result creation path as [startTest].
  String scheduleTestCase({
    required String name,
    String? fullName,
    String? testCaseName,
    List<AllureLabel> labels = const <AllureLabel>[],
    List<AllureParameter> parameters = const <AllureParameter>[],
    List<AllureLink> links = const <AllureLink>[],
  }) {
    return startTest(
      name: name,
      fullName: fullName,
      testCaseName: testCaseName,
      labels: labels,
      parameters: parameters,
      links: links,
    );
  }

  /// Applies an in-place update to a started test result.
  void updateTest(
      String testUuid, void Function(AllureTestResult result) update) {
    final state = _tests[testUuid];
    if (state == null) {
      throw StateError('Unknown test uuid: $testUuid');
    }
    update(state.result);
  }

  /// Stops a test result and resolves final status, details, and timing.
  Future<void> stopTest(
    String testUuid, {
    AllureStatus? status,
    AllureStatusDetails? statusDetails,
    Object? error,
    StackTrace? stackTrace,
    int? stop,
    int? duration,
  }) async {
    final state = _tests[testUuid];
    if (state == null) {
      throw StateError('Unknown test uuid: $testUuid');
    }

    final result = state.result;
    _notify('beforeTestStop', (listener) => listener.beforeTestStop(result));
    final resolvedStatus = status ??
        result.status ??
        (error == null
            ? AllureStatus.passed
            : getStatusFromError(error, stackTrace));
    final resolvedDetails = statusDetails ??
        (error == null
            ? result.statusDetails
            : getMessageAndTraceFromError(error, stackTrace));

    _finalizeOpenSteps(
      testUuid,
      status: resolvedStatus,
      statusDetails: resolvedDetails,
    );

    result.status ??= resolvedStatus;
    result.statusDetails = result.statusDetails.isEmpty
        ? resolvedDetails
        : result.statusDetails.merge(resolvedDetails);
    _mergeScopeMetadata(state);
    _applyAutomaticTestLabels(result);
    ensureSuiteLabels(result, state.defaultSuites);
    final dedupedLabels = _dedupeLabels(result.labels);
    result.labels
      ..clear()
      ..addAll(dedupedLabels);
    final formattedLinks =
        formatLinks(_linkUrlTemplates, _linkNameTemplates, result.links);
    result.links
      ..clear()
      ..addAll(formattedLinks);

    result.testCaseName ??= result.name;
    result.testCaseId ??=
        result.fullName == null ? null : md5Hash(result.fullName!);
    result.historyId ??= _deriveHistoryId(result);

    final normalized = normalizeTiming(
      start: result.start,
      stop: stop ?? result.stop,
      duration: duration,
    );
    result
      ..start = normalized.start
      ..stop = normalized.stop
      ..stage = _resolveTestStage(result);
    _notify('afterTestStop', (listener) => listener.afterTestStop(result));
  }

  /// Writes a stopped test result and updates linked scope completion.
  Future<void> writeTest(String testUuid) async {
    final state = _tests.remove(testUuid);
    if (state == null) {
      throw StateError('Unknown test uuid: $testUuid');
    }
    _stepStacks.remove(testUuid);

    await _ensureRunMetadataWritten();

    _notify(
      'beforeTestWrite',
      (listener) => listener.beforeTestWrite(state.result),
    );
    if (!hasSkipLabel(state.result.labels)) {
      await _writer.writeTestResult(state.result);
      _notify(
        'afterTestWrite',
        (listener) => listener.afterTestWrite(state.result),
      );
    }

    for (final scopeId in state.scopeIds) {
      final scope = _scopes[scopeId];
      if (scope == null) {
        continue;
      }
      scope.completedChildren++;
      await flushScopeIfComplete(scopeId);
    }
  }

  /// Stops and writes a test case using a serialized status value.
  Future<void> finishTestCase(
    String testUuid, {
    required String status,
    AllureStatusDetails? statusDetails,
    Object? error,
    StackTrace? stackTrace,
  }) async {
    await stopTest(
      testUuid,
      status: _parseStatus(status),
      statusDetails: statusDetails,
      error: error,
      stackTrace: stackTrace,
    );
    await writeTest(testUuid);
  }

  /// Starts a setup or teardown fixture in a scope and returns its UUID.
  String startFixture({
    required String scopeId,
    required bool before,
    required String name,
    int? start,
  }) {
    final scope = _scopes.putIfAbsent(
      scopeId,
      () => _ScopeState(id: scopeId),
    );
    final uuid = _uuid.v4();
    final result = AllureFixtureResult(
      name: name,
      stage: AllureStage.running,
      start: start ?? currentTimestamp(),
    );
    final fixture = _FixtureState(
      uuid: uuid,
      scopeId: scope.id,
      before: before,
      result: result,
    );
    _fixtures[uuid] = fixture;
    _stepStacks[uuid] = <AllureStepResult>[];
    return uuid;
  }

  /// Stops a setup or teardown fixture and records it on its scope.
  Future<void> stopFixture(
    String fixtureUuid, {
    AllureStatus? status,
    AllureStatusDetails? statusDetails,
    Object? error,
    StackTrace? stackTrace,
    int? stop,
    int? duration,
  }) async {
    final fixture = _fixtures.remove(fixtureUuid);
    if (fixture == null) {
      throw StateError('Unknown fixture uuid: $fixtureUuid');
    }

    final resolvedStatus = status ??
        fixture.result.status ??
        (error == null
            ? AllureStatus.passed
            : getStatusFromError(error, stackTrace));
    final resolvedDetails = statusDetails ??
        (error == null
            ? fixture.result.statusDetails
            : getMessageAndTraceFromError(error, stackTrace));

    _finalizeOpenSteps(
      fixtureUuid,
      status: resolvedStatus,
      statusDetails: resolvedDetails,
    );

    final normalized = normalizeTiming(
      start: fixture.result.start,
      stop: stop ?? fixture.result.stop,
      duration: duration,
    );
    fixture.result
      ..status = resolvedStatus
      ..statusDetails = fixture.result.statusDetails.isEmpty
          ? resolvedDetails
          : fixture.result.statusDetails.merge(resolvedDetails)
      ..stage = AllureStage.finished
      ..start = normalized.start
      ..stop = normalized.stop;

    _stepStacks.remove(fixtureUuid);

    final scope = _scopes.putIfAbsent(
      fixture.scopeId,
      () => _ScopeState(id: fixture.scopeId),
    );
    scope.fixtures
        .add(_RecordedFixture(before: fixture.before, result: fixture.result));
    await flushScopeIfComplete(fixture.scopeId);
  }

  /// Writes completed fixture containers for a scope.
  Future<void> writeScope(String scopeId) async {
    final scope = _scopes[scopeId];
    if (scope == null || scope.children.isEmpty) {
      return;
    }

    final children = scope.children.toList()..sort();
    for (final fixture in scope.fixtures.where((fixture) => !fixture.written)) {
      final container = AllureTestResultContainer(
        uuid: _uuid.v4(),
        name: scope.name,
        description: scope.description,
        descriptionHtml: scope.descriptionHtml,
        children: children,
        befores: fixture.before
            ? <AllureFixtureResult>[fixture.result]
            : const <AllureFixtureResult>[],
        afters: fixture.before
            ? const <AllureFixtureResult>[]
            : <AllureFixtureResult>[fixture.result],
        links: scope.links,
        start: scope.start,
        stop: currentTimestamp(),
      );
      _notify(
        'beforeContainerWrite',
        (listener) => listener.beforeContainerWrite(container),
      );
      await _writer.writeContainer(container);
      _notify(
        'afterContainerWrite',
        (listener) => listener.afterContainerWrite(container),
      );
      fixture.written = true;
    }
  }

  /// Writes a scope when its expected child count has completed.
  Future<void> flushScopeIfComplete(String scopeId) async {
    final scope = _scopes[scopeId];
    if (scope == null) {
      return;
    }
    if (scope.expectedChildrenCount == null ||
        scope.completedChildren < scope.expectedChildrenCount!) {
      return;
    }
    await writeScope(scopeId);
  }

  /// Starts a step under a test, fixture, or active parent step.
  void startStep(
    String rootUuid,
    String name, {
    int? start,
  }) {
    final stack = _stepStacks[rootUuid];
    if (stack == null) {
      throw StateError('Unknown root uuid: $rootUuid');
    }

    final step = AllureStepResult(
      uuid: _uuid.v4(),
      name: name,
      stage: AllureStage.running,
      start: start ?? currentTimestamp(),
    );

    final parent = _resolveStepParent(rootUuid);
    if (parent == null) {
      _rootExecutable(rootUuid).steps.add(step);
    } else {
      parent.steps.add(step);
    }
    stack.add(step);
  }

  /// Updates metadata for the currently running step under [rootUuid].
  void updateCurrentStep(
    String rootUuid, {
    String? name,
    List<AllureParameter> parameters = const <AllureParameter>[],
  }) {
    final stack = _stepStacks[rootUuid];
    if (stack == null || stack.isEmpty) {
      return;
    }
    final step = stack.last;
    if (name != null) {
      step.name = name;
    }
    step.parameters.addAll(parameters);
  }

  /// Stops the currently running step under [rootUuid].
  void stopStep(
    String rootUuid, {
    AllureStatus? status,
    AllureStatusDetails? statusDetails,
    int? stop,
    int? duration,
  }) {
    final stack = _stepStacks[rootUuid];
    if (stack == null || stack.isEmpty) {
      throw StateError('No step is currently running for: $rootUuid');
    }

    final step = stack.removeLast();
    _notify('beforeStepStop', (listener) => listener.beforeStepStop(step));
    final normalized = normalizeTiming(
      start: step.start,
      stop: stop ?? step.stop,
      duration: duration,
    );
    step
      ..status ??= status ?? AllureStatus.passed
      ..statusDetails = statusDetails == null || !step.statusDetails.isEmpty
          ? step.statusDetails
              .merge(statusDetails ?? const AllureStatusDetails())
          : statusDetails
      ..stage = AllureStage.finished
      ..start = normalized.start
      ..stop = normalized.stop;
    _notify('afterStepStop', (listener) => listener.afterStepStop(step));
  }

  /// Runs [body] inside a step and records pass or failure status.
  Future<T> runStep<T>(
    String testUuid,
    String name,
    FutureOr<T> Function() body,
  ) async {
    startStep(testUuid, name);
    try {
      final value = await body();
      stopStep(testUuid, status: AllureStatus.passed);
      return value;
    } catch (error, stackTrace) {
      stopStep(
        testUuid,
        status: getStatusFromError(error, stackTrace),
        statusDetails: getMessageAndTraceFromError(error, stackTrace),
      );
      rethrow;
    }
  }

  /// Adds an in-memory attachment to a test result.
  Future<void> addAttachment({
    required String testUuid,
    required String name,
    required String type,
    required List<int> content,
    String? extension,
    bool wrapInStep = false,
    int? timestamp,
  }) {
    return addAttachmentToRoot(
      testUuid,
      name: name,
      content: content,
      contentType: type,
      fileExtension: extension,
      wrapInStep: wrapInStep,
      timestamp: timestamp,
    );
  }

  /// Adds a text attachment to a test result.
  Future<void> addTextAttachment({
    required String testUuid,
    required String name,
    required String type,
    required String content,
    String? extension,
    bool wrapInStep = false,
    int? timestamp,
  }) {
    return addAttachmentToRoot(
      testUuid,
      name: name,
      content: utf8.encode(content),
      contentType: type,
      fileExtension: extension,
      wrapInStep: wrapInStep,
      timestamp: timestamp,
    );
  }

  /// Adds an in-memory attachment to any root result.
  Future<void> addAttachmentToRoot(
    String rootUuid, {
    required String name,
    required List<int> content,
    required String contentType,
    String? fileExtension,
    bool wrapInStep = false,
    int? timestamp,
  }) async {
    final attachment = await _writer.writeAttachment(
      name: name,
      content: content,
      type: contentType,
      fileExtension: fileExtension,
    );
    _attachToExecutable(
      rootUuid,
      attachment,
      wrapInStep: wrapInStep,
      timestamp: timestamp,
    );
  }

  /// Adds an attachment from a filesystem path to any root result.
  Future<void> addAttachmentPathToRoot(
    String rootUuid, {
    required String name,
    required String path,
    required String contentType,
    String? fileExtension,
    bool wrapInStep = false,
    int? timestamp,
  }) async {
    final attachment = await _writer.writeAttachmentFromPath(
      name: name,
      path: path,
      type: contentType,
      fileExtension: fileExtension,
    );
    _attachToExecutable(
      rootUuid,
      attachment,
      wrapInStep: wrapInStep,
      timestamp: timestamp,
    );
  }

  /// Adds an attachment from a byte stream to any root result.
  Future<void> addAttachmentStreamToRoot(
    String rootUuid, {
    required String name,
    required Stream<List<int>> content,
    required String contentType,
    String? fileExtension,
    bool wrapInStep = false,
    int? timestamp,
  }) async {
    final attachment = await _writer.writeAttachmentStream(
      name: name,
      content: content,
      type: contentType,
      fileExtension: fileExtension,
    );
    _attachToExecutable(
      rootUuid,
      attachment,
      wrapInStep: wrapInStep,
      timestamp: timestamp,
    );
  }

  /// Adds an attachment written through a prepared temporary file.
  Future<void> addPreparedAttachmentToRoot(
    String rootUuid, {
    required String name,
    required String contentType,
    String? fileExtension,
    required Future<void> Function(AllurePreparedAttachment attachment) write,
    bool wrapInStep = false,
    int? timestamp,
  }) async {
    final prepared = await _writer.prepareAttachment(
      name: name,
      type: contentType,
      fileExtension: fileExtension,
    );
    final attachment = await _writer.writePreparedAttachment(
      prepared,
      (_) => write(prepared),
    );
    _attachToExecutable(
      rootUuid,
      attachment,
      wrapInStep: wrapInStep,
      timestamp: timestamp,
    );
  }

  /// Adds a label directly to a started test result.
  void addLabel(String testUuid, AllureLabel label) {
    final state = _tests[testUuid];
    if (state == null) {
      throw StateError('Unknown test uuid: $testUuid');
    }
    state.result.labels.add(label);
  }

  /// Writes a run-level attachment from in-memory bytes.
  Future<void> writeGlobalAttachment({
    required String name,
    required List<int> content,
    required String type,
    String? fileExtension,
  }) async {
    await _ensureRunMetadataWritten();
    final attachment = await _writer.writeAttachment(
      name: name,
      content: content,
      type: type,
      fileExtension: fileExtension,
    );
    final globalAttachment = AllureGlobalAttachment(
      name: attachment.name,
      source: attachment.source,
      type: attachment.type,
      size: attachment.size,
      timestamp: currentTimestamp(),
    );
    _notify(
      'onGlobalAttachment',
      (listener) => listener.onGlobalAttachment(globalAttachment),
    );
    await _writer.writeGlobals(
      AllureGlobals(
        attachments: <AllureGlobalAttachment>[globalAttachment],
      ),
    );
  }

  /// Writes a run-level attachment from a filesystem path.
  Future<void> writeGlobalAttachmentFromPath({
    required String name,
    required String path,
    required String type,
    String? fileExtension,
  }) async {
    await _ensureRunMetadataWritten();
    final attachment = await _writer.writeAttachmentFromPath(
      name: name,
      path: path,
      type: type,
      fileExtension: fileExtension,
    );
    final globalAttachment = AllureGlobalAttachment(
      name: attachment.name,
      source: attachment.source,
      type: attachment.type,
      size: attachment.size,
      timestamp: currentTimestamp(),
    );
    _notify(
      'onGlobalAttachment',
      (listener) => listener.onGlobalAttachment(globalAttachment),
    );
    await _writer.writeGlobals(
      AllureGlobals(
        attachments: <AllureGlobalAttachment>[globalAttachment],
      ),
    );
  }

  /// Writes a run-level error entry.
  Future<void> writeGlobalError(AllureStatusDetails details) async {
    await _ensureRunMetadataWritten();
    final error = AllureGlobalError(
      timestamp: currentTimestamp(),
      message: details.message,
      trace: details.trace,
      known: details.known,
      muted: details.muted,
      flaky: details.flaky,
      actual: details.actual,
      expected: details.expected,
    );
    _notify('onGlobalError', (listener) => listener.onGlobalError(error));
    await _writer.writeGlobals(
      AllureGlobals(
        errors: <AllureGlobalError>[error],
      ),
    );
  }

  Future<void> _ensureRunMetadataWritten() async {
    if (_runMetadataWritten) {
      return;
    }
    _runMetadataWritten = true;
    if (_environmentInfo.isNotEmpty) {
      await _writer.writeEnvironmentInfo(_environmentInfo);
    }
    if (_categories.isNotEmpty) {
      await _writer.writeCategoriesDefinitions(_categories);
    }
    final executorInfo = _executorInfo;
    if (executorInfo != null) {
      await _writer.writeExecutorInfo(executorInfo);
    }
  }

  void _attachToExecutable(
    String rootUuid,
    AllureAttachment attachment, {
    required bool wrapInStep,
    int? timestamp,
  }) {
    _notify(
      'onAttachment',
      (listener) => listener.onAttachment(rootUuid, attachment),
    );
    final targetStep = _resolveStepParent(rootUuid);
    if (!wrapInStep) {
      if (targetStep != null) {
        targetStep.attachments.add(attachment);
      } else {
        _rootExecutable(rootUuid).attachments.add(attachment);
      }
      return;
    }

    final instant = timestamp ?? currentTimestamp();
    final wrapper = AllureStepResult(
      uuid: _uuid.v4(),
      name: attachment.name,
      attachments: <AllureAttachment>[attachment],
      status: AllureStatus.passed,
      stage: AllureStage.finished,
      start: instant,
      stop: instant,
    );
    if (targetStep != null) {
      targetStep.steps.add(wrapper);
    } else {
      _rootExecutable(rootUuid).steps.add(wrapper);
    }
  }

  void _mergeScopeMetadata(_TestState state) {
    for (final scopeId in state.scopeIds) {
      final scope = _scopes[scopeId];
      if (scope == null) {
        continue;
      }
      state.result.labels.addAll(scope.labels);
      state.result.links.addAll(scope.links);
      state.result.parameters.addAll(scope.parameters);
      state.result.description ??= scope.description;
      state.result.descriptionHtml ??= scope.descriptionHtml;
    }
  }

  void _applyAutomaticTestLabels(AllureTestResult result) {
    result.labels.addAll(getEnvironmentLabels());
    result.labels.addAll(_globalLabels);
  }

  String? _deriveHistoryId(AllureTestResult result) {
    final baseId = result.testCaseId ??
        (result.fullName == null ? null : md5Hash(result.fullName!));
    if (baseId == null) {
      return null;
    }
    final params = result.parameters
        .where((parameter) => parameter.excluded != true)
        .toList()
      ..sort((left, right) {
        final nameResult = left.name.compareTo(right.name);
        if (nameResult != 0) {
          return nameResult;
        }
        return left.value.compareTo(right.value);
      });
    final serialized = params
        .map((parameter) => '${parameter.name}:${parameter.value}')
        .join(',');
    return '$baseId:${md5Hash(serialized)}';
  }

  AllureStage _resolveTestStage(AllureTestResult result) {
    if (result.status == AllureStatus.skipped &&
        (result.stage == AllureStage.pending ||
            result.stage == AllureStage.scheduled ||
            result.stage == AllureStage.running)) {
      return AllureStage.pending;
    }
    return AllureStage.finished;
  }

  List<AllureLabel> _dedupeLabels(Iterable<AllureLabel> labels) {
    final seen = <String>{};
    final deduped = <AllureLabel>[];
    for (final label in labels) {
      final key = '${label.name}:${label.value}';
      if (seen.add(key)) {
        deduped.add(label);
      }
    }
    return deduped;
  }

  void _finalizeOpenSteps(
    String rootUuid, {
    required AllureStatus status,
    required AllureStatusDetails statusDetails,
  }) {
    final stack = _stepStacks[rootUuid];
    if (stack == null) {
      return;
    }
    while (stack.isNotEmpty) {
      stopStep(
        rootUuid,
        status: status,
        statusDetails: statusDetails,
      );
    }
  }

  AllureExecutable _rootExecutable(String rootUuid) {
    final fixture = _fixtures[rootUuid];
    if (fixture != null) {
      return fixture.result;
    }
    final test = _tests[rootUuid];
    if (test != null) {
      return test.result;
    }
    throw StateError('Unknown root uuid: $rootUuid');
  }

  AllureStepResult? _resolveStepParent(String rootUuid) {
    final stack = _stepStacks[rootUuid];
    if (stack == null || stack.isEmpty) {
      return null;
    }
    return stack.last;
  }

  AllureStatus _parseStatus(String value) {
    return switch (value) {
      'failed' => AllureStatus.failed,
      'broken' => AllureStatus.broken,
      'skipped' => AllureStatus.skipped,
      _ => AllureStatus.passed,
    };
  }

  void _notify(
    String hook,
    void Function(AllureLifecycleListener listener) callback,
  ) {
    for (final listener in _listeners) {
      try {
        callback(listener);
      } catch (error, stackTrace) {
        stderr.writeln(
          'Allure lifecycle listener failed in $hook: $error\n$stackTrace',
        );
      }
    }
  }

  AllureStatusDetails _parseStatusDetails(Object? value) {
    if (value is! Map) {
      return const AllureStatusDetails();
    }
    return AllureStatusDetails(
      message: value['message']?.toString(),
      trace: value['trace']?.toString(),
      known: value['known'] as bool?,
      muted: value['muted'] as bool?,
      flaky: value['flaky'] as bool?,
      actual: value['actual']?.toString(),
      expected: value['expected']?.toString(),
    );
  }

  AllureLabel _labelFromJson(Map value) {
    return AllureLabel(
      name: value['name'].toString(),
      value: value['value'].toString(),
    );
  }

  AllureLink _linkFromJson(Map value) {
    return AllureLink(
      url: value['url'].toString(),
      name: value['name']?.toString(),
      type: value['type']?.toString(),
    );
  }

  AllureParameter _parameterFromJson(Map value) {
    final modeValue = value['mode']?.toString();
    AllureParameterMode? mode;
    for (final candidate in AllureParameterMode.values) {
      if (candidate.value == modeValue) {
        mode = candidate;
        break;
      }
    }
    return AllureParameter(
      name: value['name'].toString(),
      value: value['value'].toString(),
      excluded: value['excluded'] as bool?,
      mode: mode,
    );
  }

  Future<void> _handleMetadata(
    String rootUuid,
    Map<String, Object?> data,
  ) async {
    final labels = (data['labels'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map(_labelFromJson)
        .toList();
    final links = (data['links'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map(_linkFromJson)
        .toList();
    final parameters =
        (data['parameters'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map(_parameterFromJson)
            .toList();
    final displayName = data['displayName']?.toString();
    final description = data['description']?.toString();
    final descriptionHtml = data['descriptionHtml']?.toString();
    final explicitHistoryId = data['historyId']?.toString();
    final explicitTestCaseId = data['testCaseId']?.toString();
    final explicitTestCaseName = data['testCaseName']?.toString();
    final statusDetails = _parseStatusDetails(data['statusDetails']);

    final fixture = _fixtures[rootUuid];
    if (fixture != null) {
      if (displayName != null) {
        fixture.result.name = displayName;
      }
      fixture.result.description = description ?? fixture.result.description;
      fixture.result.descriptionHtml =
          descriptionHtml ?? fixture.result.descriptionHtml;
      fixture.result.parameters.addAll(parameters);
      if (!statusDetails.isEmpty) {
        fixture.result.statusDetails =
            fixture.result.statusDetails.merge(statusDetails);
      }
      if (fixture.before) {
        final scope = _scopes.putIfAbsent(
          fixture.scopeId,
          () => _ScopeState(id: fixture.scopeId),
        );
        scope.labels.addAll(labels);
        scope.links.addAll(links);
        scope.parameters.addAll(parameters);
        scope.description ??= description;
        scope.descriptionHtml ??= descriptionHtml;
      }
      return;
    }

    final test = _tests[rootUuid];
    if (test == null) {
      return;
    }

    if (displayName != null) {
      test.result.name = displayName;
    }
    test.result.description = description ?? test.result.description;
    test.result.descriptionHtml =
        descriptionHtml ?? test.result.descriptionHtml;
    test.result.historyId = explicitHistoryId ?? test.result.historyId;
    test.result.testCaseId = explicitTestCaseId ?? test.result.testCaseId;
    test.result.testCaseName = explicitTestCaseName ?? test.result.testCaseName;
    if (!statusDetails.isEmpty) {
      test.result.statusDetails = test.result.statusDetails.merge(
        statusDetails,
      );
    }
    test.result.labels.addAll(labels);
    test.result.links.addAll(links);
    test.result.parameters.addAll(parameters);
  }

  /// Handles runtime messages produced by top-level Allure APIs.
  @override
  Future<void> handleRuntimeMessage(
    RuntimeMessage message, {
    required String? rootUuid,
  }) async {
    switch (message.type) {
      case 'metadata':
        if (rootUuid == null) {
          return;
        }
        await _handleMetadata(rootUuid, message.data);
        return;
      case 'step_start':
        if (rootUuid == null) {
          return;
        }
        startStep(
          rootUuid,
          message.data['name'].toString(),
          start: message.data['start'] as int?,
        );
        return;
      case 'step_metadata':
        if (rootUuid == null) {
          return;
        }
        final parameters =
            (message.data['parameters'] as List<dynamic>? ?? const <dynamic>[])
                .whereType<Map>()
                .map(_parameterFromJson)
                .toList();
        updateCurrentStep(
          rootUuid,
          name: message.data['name']?.toString(),
          parameters: parameters,
        );
        return;
      case 'step_stop':
        if (rootUuid == null) {
          return;
        }
        stopStep(
          rootUuid,
          status: message.data['status'] == null
              ? null
              : _parseStatus(message.data['status'].toString()),
          statusDetails: _parseStatusDetails(message.data['statusDetails']),
          stop: message.data['stop'] as int?,
          duration: message.data['duration'] as int?,
        );
        return;
      case 'attachment_content':
        if (rootUuid == null) {
          return;
        }
        final encoding = message.data['encoding']?.toString() ?? 'utf8';
        final rawContent = message.data['content']?.toString() ?? '';
        final bytes = encoding == 'base64'
            ? base64.decode(rawContent)
            : utf8.encode(rawContent);
        await addAttachmentToRoot(
          rootUuid,
          name: message.data['name'].toString(),
          content: bytes,
          contentType: message.data['contentType'].toString(),
          fileExtension: message.data['fileExtension']?.toString(),
          wrapInStep: message.data['wrapInStep'] == true,
          timestamp: message.data['timestamp'] as int?,
        );
        return;
      case 'attachment_path':
        if (rootUuid == null) {
          return;
        }
        await addAttachmentPathToRoot(
          rootUuid,
          name: message.data['name'].toString(),
          path: message.data['path'].toString(),
          contentType: message.data['contentType'].toString(),
          fileExtension: message.data['fileExtension']?.toString(),
          wrapInStep: message.data['wrapInStep'] == true,
          timestamp: message.data['timestamp'] as int?,
        );
        return;
      case 'global_attachment_content':
        final encoding = message.data['encoding']?.toString() ?? 'utf8';
        final rawContent = message.data['content']?.toString() ?? '';
        final bytes = encoding == 'base64'
            ? base64.decode(rawContent)
            : utf8.encode(rawContent);
        await writeGlobalAttachment(
          name: message.data['name'].toString(),
          content: bytes,
          type: message.data['contentType'].toString(),
          fileExtension: message.data['fileExtension']?.toString(),
        );
        return;
      case 'global_attachment_path':
        await writeGlobalAttachmentFromPath(
          name: message.data['name'].toString(),
          path: message.data['path'].toString(),
          type: message.data['contentType'].toString(),
          fileExtension: message.data['fileExtension']?.toString(),
        );
        return;
      case 'global_error':
        await writeGlobalError(_parseStatusDetails(message.data));
        return;
      default:
        return;
    }
  }
}

class _TestState {
  _TestState({
    required this.result,
    required this.scopeIds,
    required this.defaultSuites,
  });

  final AllureTestResult result;
  final List<String> scopeIds;
  final List<String> defaultSuites;
}

class _ScopeState {
  _ScopeState({
    required this.id,
    this.name,
  }) : start = currentTimestamp();

  final String id;
  String? name;
  final int start;
  final Set<String> children = <String>{};
  final List<_RecordedFixture> fixtures = <_RecordedFixture>[];
  final List<AllureLabel> labels = <AllureLabel>[];
  final List<AllureLink> links = <AllureLink>[];
  final List<AllureParameter> parameters = <AllureParameter>[];
  String? description;
  String? descriptionHtml;
  int? expectedChildrenCount;
  int completedChildren = 0;
}

class _FixtureState {
  _FixtureState({
    required this.uuid,
    required this.scopeId,
    required this.before,
    required this.result,
  });

  final String uuid;
  final String scopeId;
  final bool before;
  final AllureFixtureResult result;
}

class _RecordedFixture {
  _RecordedFixture({
    required this.before,
    required this.result,
  });

  final bool before;
  final AllureFixtureResult result;
  bool written = false;
}
