import 'package:path/path.dart' as p;

import 'package:allure_dart_commons/allure_dart_commons.dart';

import 'package_root.dart';

final _stackTraceFilePathPattern = RegExp(r'(file:///[^\s)]+\.dart)');

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
  final normalizedPackagePath = packagePath == null
      ? null
      : getPosixPath(packagePath);
  final titlePath = <String>[
    if (normalizedPackagePath != null)
      ..._splitPosixPath(normalizedPackagePath),
    ...groupPath,
  ];
  final fullNameParts = <String>[
    if (normalizedPackagePath != null) normalizedPackagePath,
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
    packagePath: normalizedPackagePath,
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
    links: <AllureLink>[...declarationMetadata.links, ...runtimeMetadata.links],
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
    return packageTestPathFromFilePath(suitePath);
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
    final match = _stackTraceFilePathPattern.firstMatch(line);
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

List<String> _splitPosixPath(String path) {
  if (path.isEmpty) {
    return const <String>[];
  }
  return path.split('/').where((segment) => segment.isNotEmpty).toList();
}

/// Converts a URI to a package-relative test path when possible.
String? packageTestPathFromUri(Uri? uri) {
  if (uri == null) {
    return null;
  }
  if (uri.scheme == 'file') {
    return packageTestPathFromFilePath(uri.toFilePath());
  }
  final serialized = uri.toString();
  return serialized.isEmpty ? null : serialized;
}

final _packageTestPathByAbsoluteFilePath = <String, String>{};

/// Converts a file path to a package-root-relative path when possible.
String packageTestPathFromFilePath(String filePath) {
  final absoluteFilePath = p.normalize(p.absolute(filePath));
  final cached = _packageTestPathByAbsoluteFilePath[absoluteFilePath];
  if (cached != null) {
    return cached;
  }

  final packageRoot = _findPackageRoot(absoluteFilePath);
  final result = packageRoot == null
      ? getRelativePath(filePath)
      : getPosixPath(p.relative(absoluteFilePath, from: packageRoot));
  _packageTestPathByAbsoluteFilePath[absoluteFilePath] = result;
  return result;
}

final _packageRootByDirectory = <String, String?>{};

String? _findPackageRoot(String filePath) {
  final directory = p.dirname(filePath);
  if (_packageRootByDirectory.containsKey(directory)) {
    return _packageRootByDirectory[directory];
  }
  final result = findPackageRoot(directory);
  _packageRootByDirectory[directory] = result;
  return result;
}

bool _isAdapterLibrary(
  String path, {
  required List<String> ignoredLibrarySuffixes,
}) {
  final normalized = getPosixPath(path);
  return _hasPathSuffix(normalized, 'lib/src/test_drop_in.dart') ||
      _hasPathSuffix(normalized, 'lib/src/test_api.dart') ||
      _hasPathSuffix(normalized, 'lib/src/package_test_support.dart') ||
      ignoredLibrarySuffixes.any(
        (suffix) => _hasPathSuffix(normalized, suffix),
      );
}

bool _hasPathSuffix(String path, String suffix) {
  final normalizedSuffix = getPosixPath(suffix);
  final bareSuffix = normalizedSuffix.startsWith('/')
      ? normalizedSuffix.substring(1)
      : normalizedSuffix;
  return path == bareSuffix || path.endsWith('/$bareSuffix');
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

final _allureIdAnnotationPattern = RegExp(r'@allure\.id[:=]([^\s]+)');
final _allureLabelAnnotationPattern = RegExp(
  r'@allure\.label\.([^:=\s]+)[:=]([^\s]+)',
);
final _allureLinkAnnotationPattern = RegExp(
  r'@allure\.link\.([^:=\s]+)[:=]([^\s]+)',
);
final _allureNameAnnotationPattern = RegExp(r'@allure\.name[:=]([^\s].*?)$');

/// Extracts Allure metadata annotations from [text].
ExtractedMetadata extractMetadataFromString(String text) {
  final labels = <AllureLabel>[];
  final links = <AllureLink>[];
  String? explicitAllureId;
  String? explicitDisplayName;
  var clean = text;

  final patterns = <RegExp, void Function(RegExpMatch)>{
    _allureIdAnnotationPattern: (match) {
      explicitAllureId = match.group(1);
      labels.add(AllureLabel(name: 'ALLURE_ID', value: match.group(1)!));
    },
    _allureLabelAnnotationPattern: (match) {
      labels.add(AllureLabel(name: match.group(1)!, value: match.group(2)!));
    },
    _allureLinkAnnotationPattern: (match) {
      final linkType = match.group(1);
      final value = match.group(2)!;
      links.add(AllureLink(url: value, type: linkType));
    },
    _allureNameAnnotationPattern: (match) {
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
