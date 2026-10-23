import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import 'model.dart';
import 'platform.dart';

/// Label name used to mark tests excluded by an Allure test plan.
const String allureTestPlanSkipLabel = 'ALLURE_TESTPLAN_SKIP';

/// MIME type for Allure visual comparison attachments.
///
/// See https://allurereport.org/docs/attachments/#visual-comparisons
const String allureImageDiffContentType = 'application/vnd.allure.image.diff';

/// Canonical file extension for [allureImageDiffContentType] attachments.
const String allureImageDiffExtension = 'imagediff';

/// Encodes PNG [bytes] as a `data:image/png;base64,...` data URL.
String encodeAllurePngDataUrl(List<int> bytes) {
  return 'data:image/png;base64,${base64.encode(bytes)}';
}

/// Builds the JSON body for an Allure image-diff attachment.
///
/// [expected] and [actual] must be raw PNG bytes. [diff] is optional: same-size
/// pixel mismatches usually provide it, while size mismatches may only have
/// expected/actual images.
String buildAllureImageDiffJson({
  required List<int> expected,
  required List<int> actual,
  List<int>? diff,
}) {
  final payload = <String, String>{
    'expected': encodeAllurePngDataUrl(expected),
    'actual': encodeAllurePngDataUrl(actual),
  };
  if (diff != null) {
    payload['diff'] = encodeAllurePngDataUrl(diff);
  }
  return jsonEncode(payload);
}

/// Returns the current timestamp in milliseconds since epoch.
int currentTimestamp() => DateTime.now().millisecondsSinceEpoch;

/// Resolves start and stop timestamps from optional timing values.
({int start, int stop}) normalizeTiming({
  int? start,
  int? stop,
  int? duration,
  int Function()? now,
}) {
  final nowValue = now ?? currentTimestamp;
  var resolvedStart = start;
  var resolvedStop = stop;
  int? resolvedDuration = duration;

  if (resolvedDuration != null && resolvedDuration < 0) {
    resolvedDuration = 0;
  }

  if (resolvedDuration != null) {
    if (resolvedStop != null) {
      resolvedStart = resolvedStop - resolvedDuration;
    } else if (resolvedStart != null) {
      resolvedStop = resolvedStart + resolvedDuration;
    } else {
      resolvedStop = nowValue();
      resolvedStart = resolvedStop - resolvedDuration;
    }
  } else {
    resolvedStop ??= nowValue();
    resolvedStart ??= resolvedStop;
  }

  return (start: resolvedStart.round(), stop: resolvedStop.round());
}

/// Returns the MD5 hash of [value] as a lowercase hexadecimal string.
String md5Hash(String value) => md5.convert(utf8.encode(value)).toString();

/// Serializes [value] for use in Allure parameters and details.
String serializeValue(Object? value) {
  if (value == null) {
    return 'null';
  }
  if (value is String) {
    return value;
  }
  if (value is num || value is bool) {
    return value.toString();
  }
  try {
    return jsonEncode(value);
  } catch (_) {
    return value.toString();
  }
}

/// Strips ANSI escape sequences from [value].
///
/// Mirrors allure-js `stripAnsi` (chalk/strip-ansi regex).
String stripAnsi(String value) {
  return value.replaceAll(_ansiEscapePattern, '');
}

/// Source: https://github.com/chalk/ansi-regex (used by strip-ansi).
final RegExp _ansiEscapePattern = RegExp(
  [
    r'[\u001B\u009B][[\]()#;?]*(?:(?:(?:(?:;[-a-zA-Z\d\/#&.:=?%@~_]+)*|[a-zA-Z\d]+(?:;[-a-zA-Z\d\/#&.:=?%@~_]*)*)?\u0007)',
    r'(?:(?:\d{1,4}(?:;\d{0,4})*)?[\dA-PR-TZcf-nq-uy=><~]))',
  ].join('|'),
);

/// Maps an error object to the closest Allure status.
AllureStatus getStatusFromError(Object error, [StackTrace? stackTrace]) {
  final typeName = error.runtimeType.toString().toLowerCase();
  final message = error.toString().toLowerCase();
  final trace = stackTrace?.toString().toLowerCase() ?? '';

  bool containsAssertionSignal(String value) {
    return value.contains('assert') ||
        value.contains('expectation') ||
        value.contains('matcher') ||
        value.contains('testfailure');
  }

  // Match `package:test/` and `package:matcher/`, but not `package:test_api/`
  // which appears on stacks for every framework-mediated throw (including
  // unexpected non-assertion errors that must stay `broken`).
  if (containsAssertionSignal(typeName) ||
      containsAssertionSignal(message) ||
      message.contains('expected:') ||
      trace.contains('package:matcher/') ||
      trace.contains('package:test/') ||
      _hasDynamicField(error, 'matcherResult') ||
      _hasDynamicField(error, 'actual') ||
      _hasDynamicField(error, 'expected')) {
    return AllureStatus.failed;
  }

  return AllureStatus.broken;
}

/// Extracts an Allure status message, trace, actual, and expected values.
///
/// Prefer structured fields (`actual` / `expected` / Jest-style
/// `matcherResult`) when present. For `package:test` [TestFailure] and other
/// matcher failures that only embed values in the message, fall back to
/// parsing `Expected:` / `Actual:` lines from [formatFailure].
AllureStatusDetails getMessageAndTraceFromError(
  Object error, [
  StackTrace? stackTrace,
]) {
  final actual = _readDynamicField(error, 'actual');
  final expected = _readDynamicField(error, 'expected');
  final matcherResult = _readDynamicField(error, 'matcherResult');
  // `toString()` retains the complete Dart error description (for example,
  // ArgumentError includes the invalid value and parameter name).
  final message = error.toString();

  var resolvedActual = actual == null
      ? _extractMatcherValue(matcherResult, 'actual')
      : serializeValue(actual);
  var resolvedExpected = expected == null
      ? _extractMatcherValue(matcherResult, 'expected')
      : serializeValue(expected);

  if ((resolvedActual == null || resolvedExpected == null) &&
      message.contains('Expected:') &&
      message.contains('Actual:')) {
    final parsed = _parseExpectedActualFromMessage(message);
    resolvedActual ??= parsed.actual;
    resolvedExpected ??= parsed.expected;
  }

  final dynamicStack = _readDynamicField(error, 'stack');
  final resolvedTrace = stackTrace?.toString() ?? dynamicStack?.toString();

  return AllureStatusDetails(
    message: message.isEmpty ? null : stripAnsi(message),
    trace: resolvedTrace == null ? null : stripAnsi(resolvedTrace),
    actual: resolvedActual,
    expected: resolvedExpected,
  );
}

/// Normalizes global-error inputs the same way allure-js `getGlobalErrorDetails`
/// does before transport.
///
/// Pass [error] (and optional [stackTrace]) to extract fields and infer status,
/// or pass explicit [status] with optional [details] / field overrides.
/// Explicit [status] and field arguments win over extracted values.
AllureGlobalErrorDetails getGlobalErrorDetails({
  Object? error,
  StackTrace? stackTrace,
  AllureStatus? status,
  AllureStatusDetails? details,
  String? message,
  String? trace,
  String? actual,
  String? expected,
  bool? known,
  bool? muted,
  bool? flaky,
}) {
  final Object source;
  if (error != null) {
    source = error;
  } else if (details != null) {
    source = details;
  } else {
    source = AllureStatusDetails(
      message: message,
      trace: trace,
      actual: actual,
      expected: expected,
      known: known,
      muted: muted,
      flaky: flaky,
    );
  }

  final resolvedStatus = status ?? getStatusFromError(source, stackTrace);
  final extracted = getMessageAndTraceFromError(source, stackTrace);

  // Start from extraction, then prefer source.message / source.trace the way
  // allure-js does (`error.message`, `"trace" in error`).
  var resolvedMessage = _messageFromGlobalErrorSource(source, extracted);
  var resolvedTrace = _traceFromGlobalErrorSource(source, extracted);

  // Optional details object overrides extracted source fields.
  if (details != null && !identical(details, source)) {
    if (details.message != null) {
      resolvedMessage = stripAnsi(details.message!);
    }
    if (details.trace != null) {
      resolvedTrace = stripAnsi(details.trace!);
    }
  }

  // Explicit field arguments win last.
  if (message != null) {
    resolvedMessage = stripAnsi(message);
  }
  if (trace != null) {
    resolvedTrace = stripAnsi(trace);
  }

  return AllureGlobalErrorDetails(
    status: resolvedStatus,
    message: resolvedMessage,
    trace: resolvedTrace,
    known: known ?? details?.known ?? extracted.known,
    muted: muted ?? details?.muted ?? extracted.muted,
    flaky: flaky ?? details?.flaky ?? extracted.flaky,
    actual: actual ?? details?.actual ?? extracted.actual,
    expected: expected ?? details?.expected ?? extracted.expected,
  );
}

/// Builds a `global_error` runtime message shaped like allure-js
/// `toGlobalErrorMessage`.
///
/// Status collapses to [AllureStatus.failed] or [AllureStatus.broken]. Message
/// becomes `$name failed` or `$name failed: ${details.message}`.
({String type, Map<String, Object?> data}) toGlobalErrorMessage({
  required String name,
  required AllureStatusDetails details,
  required AllureStatus status,
}) {
  final collapsedStatus = status == AllureStatus.failed
      ? AllureStatus.failed
      : AllureStatus.broken;
  final prefixedMessage = details.message == null || details.message!.isEmpty
      ? '$name failed'
      : '$name failed: ${details.message}';

  return (
    type: 'global_error',
    data: <String, Object?>{
      ...details.toJson(),
      'status': collapsedStatus.value,
      'message': prefixedMessage,
    },
  );
}

String? _messageFromGlobalErrorSource(
  Object source,
  AllureStatusDetails extracted,
) {
  if (source is AllureStatusDetails) {
    // Preserve empty strings the same way JS keeps `message: ""`.
    return source.message == null ? null : stripAnsi(source.message!);
  }
  // For ordinary Dart errors, keep `toString()` from extraction rather than
  // reducing the error to a potentially incomplete `message` field.
  return extracted.message;
}

String? _traceFromGlobalErrorSource(
  Object source,
  AllureStatusDetails extracted,
) {
  if (source is AllureStatusDetails) {
    // Preserve an explicitly supplied empty trace, but fall back to a supplied
    // StackTrace when the details object has no trace.
    return source.trace == null ? extracted.trace : stripAnsi(source.trace!);
  }
  final dynamicTrace = _readDynamicField(source, 'trace');
  if (dynamicTrace != null) {
    return stripAnsi(dynamicTrace.toString());
  }
  return extracted.trace;
}

/// Parses `package:matcher` [formatFailure] labels from an error message.
///
/// Handles prefixed messages such as `setUp failed: Expected: ...` and
/// multiline pretty-printed values.
({String? actual, String? expected}) _parseExpectedActualFromMessage(
  String message,
) {
  final expectedMatch = RegExp(
    r'Expected:\s*(.*?)(?=\n\s*Actual:)',
    dotAll: true,
  ).firstMatch(message);
  final actualMatch = RegExp(
    r'(?:^|\n)\s*Actual:\s*(.*?)(?=\n\s*(?:Which:|Expected:)|\s*$)',
    dotAll: true,
  ).firstMatch(message);

  String? normalize(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  return (
    expected: normalize(expectedMatch?.group(1)),
    actual: normalize(actualMatch?.group(1)),
  );
}

String? _extractMatcherValue(Object? value, String field) {
  final extracted = _readDynamicField(value, field);
  if (extracted == null) {
    return null;
  }
  return serializeValue(extracted);
}

bool _hasDynamicField(Object? target, String field) {
  return _readDynamicField(target, field) != null;
}

Object? _readDynamicField(Object? target, String field) {
  if (target == null) {
    return null;
  }
  if (target is AllureStatusDetails) {
    return switch (field) {
      'message' => target.message,
      'trace' => target.trace,
      'actual' => target.actual,
      'expected' => target.expected,
      'known' => target.known,
      'muted' => target.muted,
      'flaky' => target.flaky,
      _ => null,
    };
  }
  try {
    final dynamic dynamicTarget = target;
    return switch (field) {
      'matcherResult' => dynamicTarget.matcherResult,
      'actual' => dynamicTarget.actual,
      'expected' => dynamicTarget.expected,
      'inspect' => dynamicTarget.inspect,
      'message' => dynamicTarget.message,
      'trace' => dynamicTarget.trace,
      'stack' => dynamicTarget.stack,
      'known' => dynamicTarget.known,
      'muted' => dynamicTarget.muted,
      'flaky' => dynamicTarget.flaky,
      _ => null,
    };
  } catch (_) {
    return null;
  }
}

/// Builds suite labels from a hierarchy of suite names.
List<AllureLabel> getSuiteLabels(List<String> suites) {
  if (suites.isEmpty) {
    return const <AllureLabel>[];
  }
  if (suites.length == 1) {
    return <AllureLabel>[AllureLabel(name: 'suite', value: suites.first)];
  }
  if (suites.length == 2) {
    return <AllureLabel>[
      AllureLabel(name: 'parentSuite', value: suites.first),
      AllureLabel(name: 'suite', value: suites.last),
    ];
  }
  return <AllureLabel>[
    AllureLabel(name: 'parentSuite', value: suites.first),
    AllureLabel(name: 'suite', value: suites[1]),
    AllureLabel(name: 'subSuite', value: suites.skip(2).join(' > ')),
  ];
}

/// Adds default suite labels to [test] when none are already present.
void ensureSuiteLabels(AllureTestResult test, List<String> defaultSuites) {
  final existingSuiteLabels = test.labels
      .where(
        (label) =>
            label.name == 'parentSuite' ||
            label.name == 'suite' ||
            label.name == 'subSuite',
      )
      .toList();
  if (existingSuiteLabels.isNotEmpty) {
    return;
  }
  test.labels.addAll(getSuiteLabels(defaultSuites));
}

/// Adapter-generated labels that should appear at most once on a result.
///
/// Env (`ALLURE_LABEL_*`) and config global labels are applied after these
/// automatic values, so the last occurrence wins when collapsing. Matches the
/// normative adapter-generated set (`framework`, `language`, `host`,
/// `thread`, `package`, `testClass`, `testMethod`). Multi-value labels such
/// as `tag` are intentionally excluded.
const Set<String> singletonAutomaticLabelNames = <String>{
  'framework',
  'language',
  'host',
  'thread',
  'package',
  'testClass',
  'testMethod',
};

/// Converts `ALLURE_LABEL_*` environment variables to Allure labels.
List<AllureLabel> getEnvironmentLabels([Map<String, String>? environment]) {
  final source = environment ?? allureEnvironment;
  final labels = <AllureLabel>[];
  for (final entry in source.entries) {
    if (!entry.key.startsWith('ALLURE_LABEL_')) {
      continue;
    }
    final name = entry.key.substring('ALLURE_LABEL_'.length);
    if (name.isEmpty) {
      continue;
    }
    labels.add(AllureLabel(name: name, value: entry.value));
  }
  return labels;
}

/// Keeps the last value for [singletonAutomaticLabelNames], leaves others.
///
/// Used so `ALLURE_LABEL_*` / config overrides replace automatic adapter
/// labels (e.g. `host`, `framework`) instead of leaving two conflicting
/// values. Other label names may still repeat with different values.
List<AllureLabel> collapseSingletonLabels(Iterable<AllureLabel> labels) {
  final list = labels.toList(growable: false);
  final lastIndexByName = <String, int>{};
  for (var index = 0; index < list.length; index++) {
    final name = list[index].name;
    if (singletonAutomaticLabelNames.contains(name)) {
      lastIndexByName[name] = index;
    }
  }
  if (lastIndexByName.isEmpty) {
    return list;
  }
  return <AllureLabel>[
    for (var index = 0; index < list.length; index++)
      if (!lastIndexByName.containsKey(list[index].name) ||
          lastIndexByName[list[index].name] == index)
        list[index],
  ];
}

/// Returns the host label for the current machine.
///
/// When `ALLURE_LABEL_host` is set, that value is used so adapters that call
/// this helper do not invent a conflicting automatic hostname.
AllureLabel getHostLabel([Map<String, String>? environment]) {
  final source = environment ?? allureEnvironment;
  final override = source['ALLURE_LABEL_host'];
  if (override != null && override.isNotEmpty) {
    return AllureLabel(name: 'host', value: override);
  }
  return AllureLabel(name: 'host', value: allureLocalHostname);
}

/// Returns a thread label using [threadId] or the current process id.
///
/// When `ALLURE_LABEL_thread` is set and [threadId] is omitted, that value
/// overrides the automatic `pid-*` label.
AllureLabel getThreadLabel([
  String? threadId,
  Map<String, String>? environment,
]) {
  if (threadId != null) {
    return AllureLabel(name: 'thread', value: threadId);
  }
  final source = environment ?? allureEnvironment;
  final override = source['ALLURE_LABEL_thread'];
  if (override != null && override.isNotEmpty) {
    return AllureLabel(name: 'thread', value: override);
  }
  return AllureLabel(name: 'thread', value: allureProcessThreadId);
}

/// Returns a package label with [filepath] relative to the current directory.
AllureLabel getPackageLabel(String filepath) =>
    AllureLabel(name: 'package', value: getRelativePath(filepath));

/// Returns the Dart language label.
AllureLabel getLanguageLabel() =>
    const AllureLabel(name: 'language', value: 'dart');

/// Returns a framework label for [framework].
AllureLabel getFrameworkLabel(String framework) =>
    AllureLabel(name: 'framework', value: framework);

/// Returns [filepath] relative to the current directory using POSIX separators.
String getRelativePath(String filepath) {
  final current = allureCurrentDirectory;
  final relative = p.relative(filepath, from: current);
  return getPosixPath(relative);
}

/// Converts platform path separators in [filepath] to POSIX separators.
String getPosixPath(String filepath) => filepath.replaceAll('\\', '/');

/// Applies a link template to [value].
String applyLinkTemplate(String template, String value) {
  return template.contains('{}')
      ? template.replaceAll('{}', value)
      : template.replaceAll('%s', value);
}

/// Formats an Allure link with URL and name templates.
AllureLink formatLink(
  Map<String, String> urlTemplates,
  Map<String, String> nameTemplates,
  AllureLink link,
) {
  if (_isAbsoluteUrl(link.url) || link.type == null) {
    return link;
  }

  final url = urlTemplates[link.type!];
  final formattedUrl = url == null
      ? link.url
      : applyLinkTemplate(url, link.url);
  final formattedName =
      link.name ??
      (nameTemplates[link.type!] == null
          ? null
          : applyLinkTemplate(nameTemplates[link.type!]!, link.url));

  return AllureLink(url: formattedUrl, name: formattedName, type: link.type);
}

/// Formats a collection of Allure links with URL and name templates.
List<AllureLink> formatLinks(
  Map<String, String> urlTemplates,
  Map<String, String> nameTemplates,
  Iterable<AllureLink> links,
) {
  return links
      .map((link) => formatLink(urlTemplates, nameTemplates, link))
      .toList();
}

bool _isAbsoluteUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.hasScheme &&
      (uri.host.isNotEmpty || uri.scheme == 'file');
}

/// Derives an attachment file extension from explicit or inferred metadata.
String? deriveAttachmentExtension({
  String? fileExtension,
  String? originalPath,
  String? contentType,
}) {
  if (fileExtension != null && fileExtension.isNotEmpty) {
    return _normalizeExtension(fileExtension);
  }
  if (originalPath != null) {
    final ext = p.extension(originalPath);
    if (ext.isNotEmpty) {
      return _normalizeExtension(ext);
    }
  }
  if (contentType != null) {
    final derived = extensionFromMime(contentType);
    if (derived != null && derived.isNotEmpty) {
      return _normalizeExtension(derived);
    }
  }
  return null;
}

String _normalizeExtension(String value) {
  final sanitized = value.startsWith('.') ? value.substring(1) : value;
  return sanitized.isEmpty ? '' : '.$sanitized';
}

/// Whether [labels] contain the Allure test-plan skip marker.
bool hasSkipLabel(Iterable<AllureLabel> labels) {
  return labels.any((label) => label.name == allureTestPlanSkipLabel);
}

/// Serializes environment properties in `.properties` file format.
String stringifyEnvironmentInfo(AllureEnvironmentInfo info) {
  final buffer = StringBuffer();
  for (final entry in info.entries) {
    final value = entry.value;
    if (value == null) {
      continue;
    }
    buffer.writeln(
      '${_escapeProperties(entry.key)}=${_escapeProperties(value)}',
    );
  }
  return buffer.toString();
}

String _escapeProperties(String value) {
  return value
      .replaceAll('\\', '\\\\')
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r');
}
