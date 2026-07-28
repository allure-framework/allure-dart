import 'package:yaml/yaml.dart';

import 'config_loader.dart';
import 'model.dart';
import 'platform.dart';

/// Environment variable that points to an explicit Allure config file.
const String allureConfigEnvironmentVariable = 'ALLURE_CONFIG';

/// File names discovered while walking from the current directory upward.
const List<String> allureConfigFileNames = <String>[
  'allure-dart.yaml',
  'allure-dart.yml',
];

/// Configuration loaded from `allure-dart.yaml`.
class AllureConfig {
  /// Creates an Allure config value.
  const AllureConfig({
    this.resultsDirectory,
    this.globalLabels = const <AllureLabel>[],
    this.environmentInfo = const <String, String?>{},
    this.path,
  });

  /// Empty configuration that disables auto-loaded values when passed
  /// explicitly to APIs accepting [AllureConfig].
  static const AllureConfig empty = AllureConfig();

  /// Results output directory from `resultsDir` or `resultsDirectory`.
  final String? resultsDirectory;

  /// Labels added to every written test result.
  final List<AllureLabel> globalLabels;

  /// Run-level environment information written to `environment.properties`.
  final AllureEnvironmentInfo environmentInfo;

  /// Path of the config file that produced this value, when loaded from disk.
  final String? path;

  /// Loads an Allure config file.
  ///
  /// If [path] or `ALLURE_CONFIG` is set, that exact file is read. Otherwise
  /// the loader searches from [startDirectory] or the current directory upward
  /// for `allure-dart.yaml` and then `allure-dart.yml`, stopping at the nearest
  /// `pubspec.yaml` after that directory has been checked.
  factory AllureConfig.load({
    String? path,
    String? startDirectory,
    Map<String, String>? environment,
  }) {
    final env = environment ?? allureEnvironment;
    final explicitPath = path ?? env[allureConfigEnvironmentVariable];
    final baseDirectory = startDirectory ?? allureCurrentDirectory;
    return loadConfigFromFilesystem(
      explicitPath: explicitPath,
      baseDirectory: baseDirectory,
    );
  }
}

/// Parses an Allure config file body loaded from [path].
AllureConfig parseAllureConfig(String contents, {required String path}) {
  final loaded = loadYaml(contents, sourceUrl: Uri.file(path));
  if (loaded == null) {
    return AllureConfig(path: path);
  }
  if (loaded is! YamlMap) {
    throw FormatException('Allure config must be a YAML map', path);
  }

  return AllureConfig(
    resultsDirectory: _stringValue(
      loaded['resultsDir'] ?? loaded['resultsDirectory'],
    ),
    globalLabels: _parseLabels(loaded['labels']),
    environmentInfo: _parseEnvironmentInfo(loaded['environment']),
    path: path,
  );
}

List<AllureLabel> _parseLabels(Object? value) {
  if (value == null) {
    return const <AllureLabel>[];
  }
  if (value is YamlMap || value is Map) {
    return _parseLabelMap(value as Map);
  }
  if (value is YamlList || value is List) {
    return _parseLabelList(value as Iterable);
  }
  throw FormatException('Allure config labels must be a map or list');
}

List<AllureLabel> _parseLabelMap(Map value) {
  final labels = <AllureLabel>[];
  for (final entry in value.entries) {
    final name = _stringValue(entry.key);
    if (name == null || name.isEmpty) {
      continue;
    }
    final rawValue = entry.value;
    if (rawValue is YamlList || rawValue is List) {
      for (final item in rawValue as Iterable) {
        final labelValue = _stringValue(item);
        if (labelValue != null) {
          labels.add(AllureLabel(name: name, value: labelValue));
        }
      }
    } else {
      final labelValue = _stringValue(rawValue);
      if (labelValue != null) {
        labels.add(AllureLabel(name: name, value: labelValue));
      }
    }
  }
  return labels;
}

List<AllureLabel> _parseLabelList(Iterable value) {
  final labels = <AllureLabel>[];
  for (final item in value) {
    if (item is! Map) {
      throw FormatException('Allure config label list entries must be maps');
    }
    final name = _stringValue(item['name']);
    final labelValue = _stringValue(item['value']);
    if (name == null || name.isEmpty || labelValue == null) {
      continue;
    }
    labels.add(AllureLabel(name: name, value: labelValue));
  }
  return labels;
}

AllureEnvironmentInfo _parseEnvironmentInfo(Object? value) {
  if (value == null) {
    return const <String, String?>{};
  }
  if (value is! Map) {
    throw FormatException('Allure config environment must be a map');
  }
  return <String, String?>{
    for (final entry in value.entries)
      if (_stringValue(entry.key) case final key? when key.isNotEmpty)
        key: _stringValue(entry.value),
  };
}

String? _stringValue(Object? value) {
  if (value == null) {
    return null;
  }
  return value.toString();
}
