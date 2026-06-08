import 'dart:convert';
import 'dart:io';

import 'package:allure_flutter_test/allure_flutter_test.dart' as allure;
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
    final configResults = results
        .where((result) => result['name'] == 'installs via flutter_test_config')
        .toList();

    expect(
      configResults,
      isNotEmpty,
    );
    expect(
      configResults.any(
        (result) => _hasLabel(
          result['labels'] as List<dynamic>,
          name: 'module',
          value: 'allure_flutter_test',
        ),
      ),
      isTrue,
    );
    expect(
      configResults.any(
        (result) => _hasLabel(
          result['labels'] as List<dynamic>,
          name: 'framework',
          value: 'flutter-test',
        ),
      ),
      isTrue,
    );
    expect(configResults.every(_hasSteps), isTrue);
  });

  testWidgets('installs via flutter_test_config', (tester) async {
    await allure.step('verify config-installed runtime step', (_) async {
      expect(find.text('absent'), findsNothing);
    });
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

bool _hasSteps(Map<String, dynamic> result) =>
    (result['steps'] as List<dynamic>? ?? const <dynamic>[]).isNotEmpty;
