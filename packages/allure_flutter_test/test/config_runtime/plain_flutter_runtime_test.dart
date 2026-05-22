import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDownAll(() async {
    final resultsDir = Directory('allure-results');
    final resultFiles = resultsDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('-result.json'))
        .toList();

    expect(resultFiles, isNotEmpty);

    final results = resultFiles
        .map((file) =>
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)
        .toList();

    expect(
      results.any(
        (result) => _hasLabel(
          result['labels'] as List<dynamic>,
          name: 'framework',
          value: 'flutter-test',
        ),
      ),
      isTrue,
    );

    if (resultsDir.existsSync()) {
      await resultsDir.delete(recursive: true);
    }
  });

  testWidgets('installs via flutter_test_config', (tester) async {
    expect(find.text('absent'), findsNothing);
  });
}

bool _hasLabel(
  List<dynamic> labels, {
  required String name,
  required String value,
}) {
  return labels.any(
    (label) =>
        label is Map &&
        label['name']?.toString() == name &&
        label['value']?.toString() == value,
  );
}
