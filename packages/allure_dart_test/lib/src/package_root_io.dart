import 'dart:io';

import 'package:path/path.dart' as p;

/// Finds nearest directory containing `pubspec.yaml`.
String? findPackageRoot(String startDirectory) {
  var directory = startDirectory;
  while (true) {
    if (File(p.join(directory, 'pubspec.yaml')).existsSync()) {
      return directory;
    }
    final parent = p.dirname(directory);
    if (parent == directory) {
      return null;
    }
    directory = parent;
  }
}
