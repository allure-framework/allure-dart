import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:allure_dart_commons/allure_dart_commons.dart';

/// Metadata derived from a `package:test` declaration or runtime test.
class PackageTestMetadata {
  /// Creates package test metadata.
  const PackageTestMetadata({
    required this.name,
    required this.fullName,
    required this.testCaseName,
    required this.titlePath,
    required this.groupPath,
    required this.packagePath,
    required this.labels,
    required this.links,
    required this.parameters,
    required this.externalId,
    required this.nativeSelector,
    required this.rawTags,
    required this.skipped,
  });

  /// Display name for the test result.
  final String name;

  /// Fully qualified name used for selectors and history.
  final String fullName;

  /// Human-readable test case name.
  final String testCaseName;

  /// Title path used by Allure for nested test names.
  final List<String> titlePath;

  /// Group path that contains the test.
  final List<String> groupPath;

  /// Test file path relative to the package, when known.
  final String? packagePath;

  /// Labels parsed or inferred for the test.
  final List<AllureLabel> labels;

  /// Links parsed or inferred for the test.
  final List<AllureLink> links;

  /// Parameters parsed or inferred for the test.
  final List<AllureParameter> parameters;

  /// External Allure id parsed from metadata, when present.
  final String? externalId;

  /// Native selector used by Allure test plan matching.
  final String? nativeSelector;

  /// Raw `package:test` tags observed for the test.
  final List<String> rawTags;

  /// Whether the test was declared as skipped.
  final bool skipped;

  /// Best-effort class label value for the test.
  String get testClass {
    if (groupPath.isNotEmpty) {
      return groupPath.last;
    }
    if (packagePath != null) {
      return p.basenameWithoutExtension(packagePath!);
    }
    return name;
  }
}

/// Builds Allure metadata from package test declaration details.
PackageTestMetadata buildPackageTestMetadata({
  required String rawName,
  Iterable<String> rawTags = const <String>[],
  List<String> groupPath = const <String>[],
  String? packagePath,
  int retryCount = 1,
  bool skipped = false,
  String? testCaseName,
  String? nativeSelector,
  Iterable<AllureParameter> additionalParameters = const <AllureParameter>[],
}) {
  final titleMetadata = extractMetadataFromString(rawName);
  final normalizedTags = rawTags.whereType<String>().toList();

  final labels = <AllureLabel>[...titleMetadata.labels];
  final links = <AllureLink>[...titleMetadata.links];
  String? externalId = titleMetadata.allureId;

  for (final tag in normalizedTags) {
    if (tag.startsWith('@allure.')) {
      final extracted = extractMetadataFromString(tag);
      labels.addAll(extracted.labels);
      links.addAll(extracted.links);
      externalId ??= extracted.allureId;
    } else {
      labels.add(AllureLabel(name: 'tag', value: tag));
    }
  }

  final resolvedName = titleMetadata.displayName ?? titleMetadata.cleanName;
  final resolvedTestCaseName = testCaseName ?? titleMetadata.cleanName;
  final titlePath = <String>[
    if (packagePath != null) packagePath,
    ...groupPath,
  ];
  final fullNameParts = <String>[
    if (packagePath != null) packagePath,
    ...groupPath,
    resolvedName,
  ];
  final parameters = <AllureParameter>[];
  if (retryCount > 1) {
    parameters.add(
      AllureParameter(
        name: 'retry',
        value: '${retryCount - 1}',
        excluded: true,
      ),
    );
  }
  parameters.addAll(additionalParameters);

  return PackageTestMetadata(
    name: resolvedName,
    fullName: fullNameParts.isEmpty ? resolvedName : fullNameParts.join('#'),
    testCaseName: resolvedTestCaseName,
    titlePath: titlePath,
    groupPath: List<String>.unmodifiable(groupPath),
    packagePath: packagePath,
    labels: labels,
    links: links,
    parameters: parameters,
    externalId: externalId,
    nativeSelector: nativeSelector ?? fullNameParts.join('#'),
    rawTags: normalizedTags,
    skipped: skipped,
  );
}

/// Merges runtime metadata with metadata captured at declaration time.
PackageTestMetadata mergePackageTestMetadata(
  PackageTestMetadata runtimeMetadata,
  PackageTestMetadata? declarationMetadata,
) {
  if (declarationMetadata == null) {
    return runtimeMetadata;
  }
  return PackageTestMetadata(
    name: runtimeMetadata.name,
    fullName: runtimeMetadata.fullName,
    testCaseName: declarationMetadata.testCaseName,
    titlePath: runtimeMetadata.titlePath,
    groupPath: runtimeMetadata.groupPath,
    packagePath: runtimeMetadata.packagePath,
    labels: <AllureLabel>[
      ...declarationMetadata.labels,
      ...runtimeMetadata.labels,
    ],
    links: <AllureLink>[
      ...declarationMetadata.links,
      ...runtimeMetadata.links,
    ],
    parameters: <AllureParameter>[
      ...declarationMetadata.parameters,
      ...runtimeMetadata.parameters,
    ],
    externalId: declarationMetadata.externalId ?? runtimeMetadata.externalId,
    nativeSelector:
        declarationMetadata.nativeSelector ?? runtimeMetadata.nativeSelector,
    rawTags: runtimeMetadata.rawTags,
    skipped: runtimeMetadata.skipped,
  );
}

/// Builds the Allure scope id for a package test group path.
String buildPackageTestScopeId(String? packagePath, List<String> groupPath) {
  final scopeRoot = packagePath ?? '<unknown>';
  if (groupPath.isEmpty) {
    return 'group:$scopeRoot';
  }
  return 'group:$scopeRoot::${groupPath.join("::")}';
}

/// Extracts the normalized group path from a live `package:test` object.
List<String> extractPackageTestGroupPath(dynamic liveTest) {
  final rawGroups = (liveTest.groups as List<dynamic>? ?? const <dynamic>[])
      .map((group) => _maybe<String>(() => group.name)?.toString() ?? '')
      .where((name) => name.isNotEmpty)
      .toList();

  final segments = <String>[];
  String? previous;
  for (final group in rawGroups) {
    if (previous != null && group.startsWith('$previous ')) {
      segments.add(group.substring(previous.length + 1));
    } else {
      segments.add(group);
    }
    previous = group;
  }
  return segments;
}

/// Extracts the package-relative file path from a live test and location.
String? extractPackageTestPath(dynamic liveTest, dynamic location) {
  final uri = _maybe<Uri>(() => location.uri);
  if (uri == null) {
    final suitePath = _maybe<String>(() => liveTest.suite.path);
    if (suitePath == null || suitePath.isEmpty) {
      return null;
    }
    return getRelativePath(suitePath);
  }
  return packageTestPathFromUri(uri);
}

/// Normalizes package test tags from a string, iterable, or null value.
List<String> normalizePackageTestTags(Object? tags) {
  if (tags == null) {
    return const <String>[];
  }
  if (tags is String) {
    return <String>[tags];
  }
  if (tags is Iterable) {
    return tags.whereType<String>().toList();
  }
  return const <String>[];
}

/// Resolves a package test path from declaration metadata or a stack trace.
String? resolvePackageTestPathFromDeclaration({
  Uri? locationUri,
  StackTrace? stackTrace,
  List<String> ignoredLibrarySuffixes = const <String>[],
}) {
  final direct = packageTestPathFromUri(locationUri);
  if (direct != null) {
    return direct;
  }

  final trace = stackTrace ?? StackTrace.current;
  for (final line in trace.toString().split('\n')) {
    final match = RegExp(r'(file:///[^\s)]+\.dart)').firstMatch(line);
    if (match == null) {
      continue;
    }
    final uri = Uri.tryParse(match.group(1)!);
    final candidate = packageTestPathFromUri(uri);
    if (candidate == null ||
        _isAdapterLibrary(
          candidate,
          ignoredLibrarySuffixes: ignoredLibrarySuffixes,
        )) {
      continue;
    }
    return candidate;
  }
  return null;
}

/// Converts a URI to a package-relative test path when possible.
String? packageTestPathFromUri(Uri? uri) {
  if (uri == null) {
    return null;
  }
  if (uri.scheme == 'file') {
    return getRelativePath(uri.toFilePath());
  }
  final serialized = uri.toString();
  return serialized.isEmpty ? null : serialized;
}

bool _isAdapterLibrary(
  String path, {
  required List<String> ignoredLibrarySuffixes,
}) {
  final normalized = getPosixPath(path);
  return normalized.endsWith('/lib/src/test_drop_in.dart') ||
      normalized.endsWith('/lib/src/test_api.dart') ||
      normalized.endsWith('/lib/src/package_test_support.dart') ||
      ignoredLibrarySuffixes.any(normalized.endsWith);
}

T? _maybe<T>(T Function() getter) {
  try {
    return getter();
  } catch (_) {
    return null;
  }
}

/// Metadata extracted from inline Allure annotations in text.
class ExtractedMetadata {
  /// Creates extracted metadata.
  const ExtractedMetadata({
    required this.cleanName,
    this.allureId,
    this.displayName,
    this.labels = const <AllureLabel>[],
    this.links = const <AllureLink>[],
  });

  /// Text with Allure annotations removed.
  final String cleanName;

  /// Parsed Allure id, when present.
  final String? allureId;

  /// Parsed display name override, when present.
  final String? displayName;

  /// Parsed Allure labels.
  final List<AllureLabel> labels;

  /// Parsed Allure links.
  final List<AllureLink> links;
}

/// Extracts Allure metadata annotations from [text].
ExtractedMetadata extractMetadataFromString(String text) {
  final labels = <AllureLabel>[];
  final links = <AllureLink>[];
  String? explicitAllureId;
  String? explicitDisplayName;
  var clean = text;

  final patterns = <RegExp, void Function(RegExpMatch)>{
    RegExp(r'@allure\.id[:=]([^\s]+)'): (match) {
      explicitAllureId = match.group(1);
      labels.add(AllureLabel(name: 'ALLURE_ID', value: match.group(1)!));
    },
    RegExp(r'@allure\.label\.([^:=\s]+)[:=]([^\s]+)'): (match) {
      labels.add(AllureLabel(name: match.group(1)!, value: match.group(2)!));
    },
    RegExp(r'@allure\.link\.([^:=\s]+)[:=]([^\s]+)'): (match) {
      final linkType = match.group(1);
      final value = match.group(2)!;
      links.add(AllureLink(url: value, type: linkType));
    },
    RegExp(r'@allure\.name[:=]([^\s].*?)$'): (match) {
      explicitDisplayName = match.group(1)?.trim();
    },
  };

  for (final entry in patterns.entries) {
    final matches = entry.key.allMatches(clean).toList();
    for (final match in matches) {
      entry.value(match);
    }
    clean = clean
        .replaceAll(entry.key, '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  return ExtractedMetadata(
    cleanName: clean.isEmpty ? text : clean,
    allureId: explicitAllureId,
    displayName: explicitDisplayName,
    labels: labels,
    links: links,
  );
}

/// Single entry in an Allure test plan.
class TestPlanEntry {
  /// Creates a test plan entry.
  const TestPlanEntry({this.id, this.selector});

  /// Optional Allure id to match.
  final Object? id;

  /// Optional full-name or native selector to match.
  final String? selector;
}

/// Parsed Allure test plan version 1.
class TestPlanV1 {
  /// Creates a test plan.
  const TestPlanV1({required this.tests});

  /// Entries included in the test plan.
  final List<TestPlanEntry> tests;
}

/// Parses an Allure test plan from `ALLURE_TESTPLAN_PATH`.
TestPlanV1? parseTestPlan([Map<String, String>? environment]) {
  final source = environment ?? Platform.environment;
  final path = source['ALLURE_TESTPLAN_PATH'];
  if (path == null || path.isEmpty) {
    return null;
  }

  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Allure: test plan file does not exist: $path');
    return null;
  }

  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, dynamic>) {
      stderr.writeln('Allure: test plan root must be a JSON object: $path');
      return null;
    }
    final version = decoded['version'];
    if (version != null && version.toString() != '1.0') {
      stderr.writeln('Allure: unsupported test plan version: $version');
      return null;
    }
    final tests = decoded['tests'];
    if (tests is! List) {
      stderr.writeln('Allure: test plan does not contain a tests array');
      return null;
    }
    final entries = tests
        .whereType<Map>()
        .where((entry) {
          final hasId = entry['id'] != null;
          final hasSelector = entry['selector'] != null &&
              entry['selector'].toString().isNotEmpty;
          if (!hasId && !hasSelector) {
            stderr.writeln('Allure: ignoring malformed test plan entry');
          }
          return hasId || hasSelector;
        })
        .map(
          (entry) => TestPlanEntry(
            id: entry['id'],
            selector: entry['selector']?.toString(),
          ),
        )
        .toList();
    if (entries.isEmpty) {
      return null;
    }
    return TestPlanV1(tests: entries);
  } catch (error) {
    stderr.writeln('Allure: unable to parse test plan: $error');
    return null;
  }
}

/// Whether a test identified by id, selector, or tags is included in [plan].
bool includedInTestPlan(
  TestPlanV1 plan, {
  String? id,
  String? fullName,
  String? nativeSelector,
  Iterable<String>? tags,
}) {
  final effectiveId = id ?? _extractAllureIdFromTags(tags);

  for (final entry in plan.tests) {
    final idMatched = effectiveId != null &&
        entry.id != null &&
        entry.id.toString() == effectiveId;
    final selectorMatched = fullName != null &&
        entry.selector != null &&
        entry.selector == fullName;
    final nativeSelectorMatched = nativeSelector != null &&
        entry.selector != null &&
        entry.selector == nativeSelector;
    if (idMatched || selectorMatched || nativeSelectorMatched) {
      return true;
    }
  }
  return false;
}

/// Extracts an Allure id from tag expressions.
String? extractAllureIdFromTags(Iterable<String>? tags) {
  return _extractAllureIdFromTags(tags);
}

/// Adds the Allure test-plan skip marker to [labels].
void addSkipLabel(List<AllureLabel> labels) {
  labels.add(const AllureLabel(name: allureTestPlanSkipLabel, value: 'true'));
}

String? _extractAllureIdFromTags(Iterable<String>? tags) {
  if (tags == null) {
    return null;
  }
  final expressions = <RegExp>[
    RegExp(r'^@allure\.id=(.+)$'),
    RegExp(r'^@allure\.id:(.+)$'),
  ];
  for (final tag in tags) {
    for (final expression in expressions) {
      final match = expression.firstMatch(tag);
      if (match != null) {
        return match.group(1);
      }
    }
  }
  return null;
}
