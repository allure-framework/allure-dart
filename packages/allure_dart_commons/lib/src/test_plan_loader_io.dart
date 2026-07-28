import 'dart:io';

import 'platform.dart';

/// Reads an Allure test plan from [path], if present.
String? loadTestPlanContents(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    allureLogWarning('Allure: test plan file does not exist: $path');
    return null;
  }
  return file.readAsStringSync();
}
