import 'dart:io';

import 'package:path/path.dart' as p;

import 'config.dart';

/// Loads an explicit or discovered config file from the local filesystem.
AllureConfig loadConfigFromFilesystem({
  required String? explicitPath,
  required String baseDirectory,
}) {
  final file = explicitPath == null || explicitPath.isEmpty
      ? _findConfigFile(baseDirectory)
      : File(
          p.isAbsolute(explicitPath)
              ? explicitPath
              : p.join(baseDirectory, explicitPath),
        );

  if (file == null) {
    return AllureConfig.empty;
  }
  return _loadFromFile(file);
}

AllureConfig _loadFromFile(File file) {
  if (!file.existsSync()) {
    throw FileSystemException('Allure config file does not exist', file.path);
  }
  return parseAllureConfig(file.readAsStringSync(), path: file.path);
}

File? _findConfigFile(String startDirectory) {
  var directory = p.normalize(p.absolute(startDirectory));
  if (FileSystemEntity.isFileSync(directory)) {
    directory = p.dirname(directory);
  }

  while (true) {
    for (final fileName in allureConfigFileNames) {
      final file = File(p.join(directory, fileName));
      if (file.existsSync()) {
        return file;
      }
    }
    if (File(p.join(directory, 'pubspec.yaml')).existsSync()) {
      return null;
    }
    final parent = p.dirname(directory);
    if (parent == directory) {
      return null;
    }
    directory = parent;
  }
}
