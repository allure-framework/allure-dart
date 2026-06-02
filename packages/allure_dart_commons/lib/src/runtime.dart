import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'model.dart';
import 'utils.dart';

/// Message sent from a test runtime API to an Allure lifecycle sink.
class RuntimeMessage {
  /// Creates a runtime message with a [type] and optional [data] payload.
  const RuntimeMessage({
    required this.type,
    this.data = const <String, Object?>{},
  });

  /// Message type understood by [AllureRuntimeMessageSink].
  final String type;

  /// Message payload.
  final Map<String, Object?> data;

  /// Whether this message targets run-level data instead of a test context.
  bool get isGlobal => type.startsWith('global_');
}

/// Consumer of runtime messages emitted by test-facing APIs.
abstract class AllureRuntimeMessageSink {
  /// Creates a runtime message sink.
  AllureRuntimeMessageSink();

  /// Handles a [message] for the current root result identified by [rootUuid].
  Future<void> handleRuntimeMessage(
    RuntimeMessage message, {
    required String? rootUuid,
  });
}

/// Active Allure execution identifiers for zone-based runtime APIs.
class AllureExecutionContext {
  /// Creates an execution context.
  const AllureExecutionContext({
    required this.rootUuid,
    required this.testUuid,
  });

  /// UUID of the root test or fixture receiving runtime messages.
  final String rootUuid;

  /// UUID of the logical test associated with the execution.
  final String testUuid;
}

/// Resolves the current Allure execution context.
typedef AllureExecutionContextResolver = AllureExecutionContext? Function();

/// Runtime transport used by top-level Allure APIs.
abstract class TestRuntime {
  /// Creates a test runtime.
  TestRuntime();

  /// Sends a runtime [message].
  Future<void> send(RuntimeMessage message);
}

/// Runtime transport that intentionally drops all messages.
class NoopTestRuntime implements TestRuntime {
  /// Creates a no-op runtime.
  const NoopTestRuntime();

  /// Drops [message] without side effects.
  @override
  Future<void> send(RuntimeMessage message) async {}
}

/// Runtime transport that forwards messages to an [AllureRuntimeMessageSink].
class MessageTestRuntime implements TestRuntime {
  /// Creates a message runtime with a sink and context resolver.
  MessageTestRuntime({
    required AllureRuntimeMessageSink sink,
    required AllureExecutionContextResolver contextResolver,
  })  : _sink = sink,
        _contextResolver = contextResolver;

  final AllureRuntimeMessageSink _sink;
  final AllureExecutionContextResolver _contextResolver;

  /// Sends [message] to the sink when a context is available.
  @override
  Future<void> send(RuntimeMessage message) {
    final context = _contextResolver();
    if (!message.isGlobal && context == null) {
      return Future<void>.value();
    }
    return _sink.handleRuntimeMessage(
      message,
      rootUuid: context?.rootUuid,
    );
  }
}

TestRuntime _globalTestRuntime = const NoopTestRuntime();

/// Replaces the process-wide Allure runtime used by top-level APIs.
void setGlobalTestRuntime(TestRuntime runtime) {
  _globalTestRuntime = runtime;
}

/// Returns the process-wide Allure runtime used by top-level APIs.
TestRuntime getGlobalTestRuntime() => _globalTestRuntime;

/// Returns the process-wide Allure runtime, preserving compatibility.
TestRuntime getGlobalTestRuntimeWithAutoconfig() => _globalTestRuntime;

/// Adds a single Allure label to the current test.
Future<void> label(String name, String value) {
  return _globalTestRuntime.send(
    RuntimeMessage(
      type: 'metadata',
      data: <String, Object?>{
        'labels': <Map<String, String>>[
          AllureLabel(name: name, value: value).toJson(),
        ],
      },
    ),
  );
}

/// Adds multiple Allure labels to the current test.
Future<void> labels(Iterable<AllureLabel> values) {
  return _globalTestRuntime.send(
    RuntimeMessage(
      type: 'metadata',
      data: <String, Object?>{
        'labels': values.map((label) => label.toJson()).toList(),
      },
    ),
  );
}

/// Adds an Allure link to the current test.
Future<void> link(
  String url, {
  String? name,
  String? type,
}) {
  return links(<AllureLink>[AllureLink(url: url, name: name, type: type)]);
}

/// Adds multiple Allure links to the current test.
Future<void> links(Iterable<AllureLink> values) {
  return _globalTestRuntime.send(
    RuntimeMessage(
      type: 'metadata',
      data: <String, Object?>{
        'links': values.map((link) => link.toJson()).toList(),
      },
    ),
  );
}

/// Adds an Allure parameter to the current test.
Future<void> parameter(
  String name,
  Object? value, {
  bool? excluded,
  AllureParameterMode? mode,
}) {
  return _globalTestRuntime.send(
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
  );
}

/// Sets the Markdown description for the current test.
Future<void> description(String markdown) {
  return _globalTestRuntime.send(
    RuntimeMessage(
      type: 'metadata',
      data: <String, Object?>{'description': markdown},
    ),
  );
}

/// Sets the HTML description for the current test.
Future<void> descriptionHtml(String html) {
  return _globalTestRuntime.send(
    RuntimeMessage(
      type: 'metadata',
      data: <String, Object?>{'descriptionHtml': html},
    ),
  );
}

/// Overrides the display name of the current test.
Future<void> displayName(String name) {
  return _globalTestRuntime.send(
    RuntimeMessage(
      type: 'metadata',
      data: <String, Object?>{'displayName': name},
    ),
  );
}

/// Sets the history id of the current test.
Future<void> historyId(String value) {
  return _globalTestRuntime.send(
    RuntimeMessage(
      type: 'metadata',
      data: <String, Object?>{'historyId': value},
    ),
  );
}

/// Sets the test case id of the current test.
Future<void> testCaseId(String value) {
  return _globalTestRuntime.send(
    RuntimeMessage(
      type: 'metadata',
      data: <String, Object?>{'testCaseId': value},
    ),
  );
}

/// Sets the test case name of the current test.
Future<void> testCaseName(String value) {
  return _globalTestRuntime.send(
    RuntimeMessage(
      type: 'metadata',
      data: <String, Object?>{'testCaseName': value},
    ),
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
  return _globalTestRuntime.send(
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
  );
}

/// Marks the current test status details as known.
Future<void> markKnown({bool value = true}) {
  return statusDetails(known: value);
}

/// Marks the current test status details as muted.
Future<void> markMuted({bool value = true}) {
  return statusDetails(muted: value);
}

/// Marks the current test status details as flaky.
Future<void> markFlaky({bool value = true}) {
  return statusDetails(flaky: value);
}

/// Adds an attachment from in-memory [content] to the current test.
Future<void> attachment(
  String name,
  Object content, {
  required String contentType,
  String? fileExtension,
  bool wrapInStep = true,
  int? timestamp,
}) {
  final payload = _encodeAttachmentContent(content);
  return _globalTestRuntime.send(
    RuntimeMessage(
      type: 'attachment_content',
      data: <String, Object?>{
        'name': name,
        'content': payload.content,
        'encoding': payload.encoding,
        'contentType': contentType,
        'fileExtension': fileExtension,
        'wrapInStep': wrapInStep,
        'timestamp': timestamp,
      },
    ),
  );
}

/// Adds an attachment from a filesystem [path] to the current test.
Future<void> attachmentPath(
  String name,
  String path, {
  required String contentType,
  String? fileExtension,
  bool wrapInStep = true,
  int? timestamp,
}) {
  return _globalTestRuntime.send(
    RuntimeMessage(
      type: 'attachment_path',
      data: <String, Object?>{
        'name': name,
        'path': path,
        'contentType': contentType,
        'fileExtension': fileExtension,
        'wrapInStep': wrapInStep,
        'timestamp': timestamp,
      },
    ),
  );
}

/// Adds a Playwright trace attachment from [path] to the current test.
Future<void> attachTrace(String name, String path) {
  return attachmentPath(
    name,
    path,
    contentType: 'application/vnd.allure.playwright-trace',
  );
}

/// Writes a run-level attachment from in-memory [content].
Future<void> globalAttachment(
  String name,
  Object content, {
  required String contentType,
  String? fileExtension,
}) {
  final payload = _encodeAttachmentContent(content);
  return _globalTestRuntime.send(
    RuntimeMessage(
      type: 'global_attachment_content',
      data: <String, Object?>{
        'name': name,
        'content': payload.content,
        'encoding': payload.encoding,
        'contentType': contentType,
        'fileExtension': fileExtension,
      },
    ),
  );
}

/// Writes a run-level attachment from a filesystem [path].
Future<void> globalAttachmentPath(
  String name,
  String path, {
  required String contentType,
  String? fileExtension,
}) {
  return _globalTestRuntime.send(
    RuntimeMessage(
      type: 'global_attachment_path',
      data: <String, Object?>{
        'name': name,
        'path': path,
        'contentType': contentType,
        'fileExtension': fileExtension,
      },
    ),
  );
}

/// Writes a run-level error entry.
Future<void> globalError({
  String? message,
  String? trace,
  bool? known,
  bool? muted,
  bool? flaky,
  String? actual,
  String? expected,
}) {
  return _globalTestRuntime.send(
    RuntimeMessage(
      type: 'global_error',
      data: <String, Object?>{
        'message': message,
        'trace': trace,
        'known': known,
        'muted': muted,
        'flaky': flaky,
        'actual': actual,
        'expected': expected,
      },
    ),
  );
}

/// Records an already-completed step with [status].
Future<void> logStep(
  String name, {
  AllureStatus status = AllureStatus.passed,
  Object? error,
}) async {
  final timestamp = currentTimestamp();
  await _globalTestRuntime.send(
    RuntimeMessage(
      type: 'step_start',
      data: <String, Object?>{'name': name, 'start': timestamp},
    ),
  );
  await _globalTestRuntime.send(
    RuntimeMessage(
      type: 'step_stop',
      data: <String, Object?>{
        'status': status.value,
        'stop': timestamp,
        'statusDetails':
            error == null ? null : getMessageAndTraceFromError(error).toJson(),
      },
    ),
  );
}

/// Runs [body] inside an Allure step and records its outcome.
Future<T> step<T>(
  String name,
  FutureOr<T> Function(AllureStepContext step) body,
) async {
  await _globalTestRuntime.send(
    RuntimeMessage(
      type: 'step_start',
      data: <String, Object?>{'name': name, 'start': currentTimestamp()},
    ),
  );

  try {
    final result = await body(const AllureStepContext());
    await _globalTestRuntime.send(
      RuntimeMessage(
        type: 'step_stop',
        data: <String, Object?>{
          'status': AllureStatus.passed.value,
          'stop': currentTimestamp(),
        },
      ),
    );
    return result;
  } catch (error, stackTrace) {
    await _globalTestRuntime.send(
      RuntimeMessage(
        type: 'step_stop',
        data: <String, Object?>{
          'status': getStatusFromError(error, stackTrace).value,
          'stop': currentTimestamp(),
          'statusDetails':
              getMessageAndTraceFromError(error, stackTrace).toJson(),
        },
      ),
    );
    rethrow;
  }
}

/// Context object passed to an active Allure step body.
class AllureStepContext {
  /// Creates a step context.
  const AllureStepContext();

  /// Overrides the display name of the current step.
  Future<void> displayName(String name) {
    return _globalTestRuntime.send(
      RuntimeMessage(
        type: 'step_metadata',
        data: <String, Object?>{'name': name},
      ),
    );
  }

  /// Adds a parameter to the current step.
  Future<void> parameter(
    String name,
    Object? value, {
    AllureParameterMode? mode,
  }) {
    return _globalTestRuntime.send(
      RuntimeMessage(
        type: 'step_metadata',
        data: <String, Object?>{
          'parameters': <Map<String, Object?>>[
            AllureParameter(
              name: name,
              value: serializeValue(value),
              mode: mode,
            ).toJson(),
          ],
        },
      ),
    );
  }
}

/// Adds an issue link to the current test.
Future<void> issue(String value, {String? name}) =>
    link(value, name: name, type: 'issue');

/// Adds a test management system link to the current test.
Future<void> tms(String value, {String? name}) =>
    link(value, name: name, type: 'tms');

/// Adds an Allure id label to the current test.
Future<void> allureId(String value) => label('ALLURE_ID', value);

/// Adds an epic label to the current test.
Future<void> epic(String value) => label('epic', value);

/// Adds a feature label to the current test.
Future<void> feature(String value) => label('feature', value);

/// Adds a story label to the current test.
Future<void> story(String value) => label('story', value);

/// Adds a suite label to the current test.
Future<void> suite(String value) => label('suite', value);

/// Adds a parent suite label to the current test.
Future<void> parentSuite(String value) => label('parentSuite', value);

/// Adds a sub-suite label to the current test.
Future<void> subSuite(String value) => label('subSuite', value);

/// Adds an owner label to the current test.
Future<void> owner(String value) => label('owner', value);

/// Adds a severity label to the current test.
Future<void> severity(String value) => label('severity', value);

/// Adds a layer label to the current test.
Future<void> layer(String value) => label('layer', value);

/// Adds a tag label to the current test.
Future<void> tag(String value) => label('tag', value);

/// Adds tag labels to the current test.
Future<void> tags(Iterable<String> values) {
  return labels(values.map((value) => AllureLabel(name: 'tag', value: value)));
}

({String encoding, String content}) _encodeAttachmentContent(Object value) {
  if (value is List<int>) {
    return (
      encoding: 'base64',
      content: base64.encode(value),
    );
  }
  if (value is Uint8List) {
    return (
      encoding: 'base64',
      content: base64.encode(value),
    );
  }
  if (value is String) {
    return (encoding: 'utf8', content: value);
  }
  return (
    encoding: 'utf8',
    content: serializeValue(value),
  );
}
