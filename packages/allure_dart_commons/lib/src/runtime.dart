import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'model.dart';
import 'utils.dart';

class RuntimeMessage {
  const RuntimeMessage({
    required this.type,
    this.data = const <String, Object?>{},
  });

  final String type;
  final Map<String, Object?> data;

  bool get isGlobal => type.startsWith('global_');
}

abstract class AllureRuntimeMessageSink {
  Future<void> handleRuntimeMessage(
    RuntimeMessage message, {
    required String? rootUuid,
  });
}

class AllureExecutionContext {
  const AllureExecutionContext({
    required this.rootUuid,
    required this.testUuid,
  });

  final String rootUuid;
  final String testUuid;
}

typedef AllureExecutionContextResolver = AllureExecutionContext? Function();

abstract class TestRuntime {
  Future<void> send(RuntimeMessage message);
}

class NoopTestRuntime implements TestRuntime {
  const NoopTestRuntime();

  @override
  Future<void> send(RuntimeMessage message) async {}
}

class MessageTestRuntime implements TestRuntime {
  MessageTestRuntime({
    required AllureRuntimeMessageSink sink,
    required AllureExecutionContextResolver contextResolver,
  })  : _sink = sink,
        _contextResolver = contextResolver;

  final AllureRuntimeMessageSink _sink;
  final AllureExecutionContextResolver _contextResolver;

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

void setGlobalTestRuntime(TestRuntime runtime) {
  _globalTestRuntime = runtime;
}

TestRuntime getGlobalTestRuntime() => _globalTestRuntime;

TestRuntime getGlobalTestRuntimeWithAutoconfig() => _globalTestRuntime;

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

Future<void> link(
  String url, {
  String? name,
  String? type,
}) {
  return links(<AllureLink>[AllureLink(url: url, name: name, type: type)]);
}

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

Future<void> description(String markdown) {
  return _globalTestRuntime.send(
    RuntimeMessage(
      type: 'metadata',
      data: <String, Object?>{'description': markdown},
    ),
  );
}

Future<void> descriptionHtml(String html) {
  return _globalTestRuntime.send(
    RuntimeMessage(
      type: 'metadata',
      data: <String, Object?>{'descriptionHtml': html},
    ),
  );
}

Future<void> displayName(String name) {
  return _globalTestRuntime.send(
    RuntimeMessage(
      type: 'metadata',
      data: <String, Object?>{'displayName': name},
    ),
  );
}

Future<void> historyId(String value) {
  return _globalTestRuntime.send(
    RuntimeMessage(
      type: 'metadata',
      data: <String, Object?>{'historyId': value},
    ),
  );
}

Future<void> testCaseId(String value) {
  return _globalTestRuntime.send(
    RuntimeMessage(
      type: 'metadata',
      data: <String, Object?>{'testCaseId': value},
    ),
  );
}

Future<void> testCaseName(String value) {
  return _globalTestRuntime.send(
    RuntimeMessage(
      type: 'metadata',
      data: <String, Object?>{'testCaseName': value},
    ),
  );
}

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

Future<void> markKnown({bool value = true}) {
  return statusDetails(known: value);
}

Future<void> markMuted({bool value = true}) {
  return statusDetails(muted: value);
}

Future<void> markFlaky({bool value = true}) {
  return statusDetails(flaky: value);
}

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

Future<void> attachTrace(String name, String path) {
  return attachmentPath(
    name,
    path,
    contentType: 'application/vnd.allure.playwright-trace',
  );
}

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

class AllureStepContext {
  const AllureStepContext();

  Future<void> displayName(String name) {
    return _globalTestRuntime.send(
      RuntimeMessage(
        type: 'step_metadata',
        data: <String, Object?>{'name': name},
      ),
    );
  }

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

Future<void> issue(String value, {String? name}) =>
    link(value, name: name, type: 'issue');

Future<void> tms(String value, {String? name}) =>
    link(value, name: name, type: 'tms');

Future<void> allureId(String value) => label('ALLURE_ID', value);

Future<void> epic(String value) => label('epic', value);

Future<void> feature(String value) => label('feature', value);

Future<void> story(String value) => label('story', value);

Future<void> suite(String value) => label('suite', value);

Future<void> parentSuite(String value) => label('parentSuite', value);

Future<void> subSuite(String value) => label('subSuite', value);

Future<void> owner(String value) => label('owner', value);

Future<void> severity(String value) => label('severity', value);

Future<void> layer(String value) => label('layer', value);

Future<void> tag(String value) => label('tag', value);

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
