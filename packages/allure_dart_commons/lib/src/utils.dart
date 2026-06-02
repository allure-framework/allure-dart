import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import 'model.dart';

/// Label name used to mark tests excluded by an Allure test plan.
const String allureTestPlanSkipLabel = 'ALLURE_TESTPLAN_SKIP';

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

/// Maps an error object to the closest Allure status.
AllureStatus getStatusFromError(Object error, [StackTrace? stackTrace]) {
  final typeName = error.runtimeType.toString().toLowerCase();
  final message = error.toString().toLowerCase();
  final trace = stackTrace?.toString().toLowerCase() ?? '';

  bool containsAssertionSignal(String value) {
    return value.contains('assert') ||
        value.contains('expectation') ||
        value.contains('matcher');
  }

  if (containsAssertionSignal(typeName) ||
      containsAssertionSignal(message) ||
      trace.contains('package:matcher') ||
      trace.contains('package:test') ||
      _hasDynamicField(error, 'matcherResult') ||
      _hasDynamicField(error, 'actual') ||
      _hasDynamicField(error, 'expected')) {
    return AllureStatus.failed;
  }

  return AllureStatus.broken;
}

/// Extracts an Allure status message, trace, actual, and expected values.
AllureStatusDetails getMessageAndTraceFromError(
  Object error, [
  StackTrace? stackTrace,
]) {
  final actual = _readDynamicField(error, 'actual');
  final expected = _readDynamicField(error, 'expected');
  final matcherResult = _readDynamicField(error, 'matcherResult');

  return AllureStatusDetails(
    message: error.toString(),
    trace: stackTrace?.toString(),
    actual: actual == null
        ? _extractMatcherValue(matcherResult, 'actual')
        : serializeValue(actual),
    expected: expected == null
        ? _extractMatcherValue(matcherResult, 'expected')
        : serializeValue(expected),
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
  try {
    final dynamic dynamicTarget = target;
    return switch (field) {
      'matcherResult' => dynamicTarget.matcherResult,
      'actual' => dynamicTarget.actual,
      'expected' => dynamicTarget.expected,
      'inspect' => dynamicTarget.inspect,
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
    AllureLabel(name: 'subSuite', value: suites.skip(2).join(' / ')),
  ];
}

/// Adds default suite labels to [test] when none are already present.
void ensureSuiteLabels(AllureTestResult test, List<String> defaultSuites) {
  final existingSuiteLabels = test.labels
      .where((label) =>
          label.name == 'parentSuite' ||
          label.name == 'suite' ||
          label.name == 'subSuite')
      .toList();
  if (existingSuiteLabels.isNotEmpty) {
    return;
  }
  test.labels.addAll(getSuiteLabels(defaultSuites));
}

/// Converts `ALLURE_LABEL_*` environment variables to Allure labels.
List<AllureLabel> getEnvironmentLabels([Map<String, String>? environment]) {
  final source = environment ?? Platform.environment;
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

/// Returns the host label for the current machine.
AllureLabel getHostLabel() =>
    AllureLabel(name: 'host', value: Platform.localHostname);

/// Returns a thread label using [threadId] or the current process id.
AllureLabel getThreadLabel([String? threadId]) => AllureLabel(
      name: 'thread',
      value: threadId ?? 'pid-$pid',
    );

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
  final current = Directory.current.path;
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
  final formattedUrl =
      url == null ? link.url : applyLinkTemplate(url, link.url);
  final formattedName = link.name ??
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
    buffer
        .writeln('${_escapeProperties(entry.key)}=${_escapeProperties(value)}');
  }
  return buffer.toString();
}

String _escapeProperties(String value) {
  return value
      .replaceAll('\\', '\\\\')
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r');
}
