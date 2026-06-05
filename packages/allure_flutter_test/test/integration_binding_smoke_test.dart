import 'dart:convert';
import 'dart:io';

import 'package:allure_flutter_test/integration_test.dart';

void main() {
  final resultsDir = Directory('allure-results');

  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDownAll(() async {
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
    final integrationResults = results
        .where((result) => result['name'] == 'labels integration binding tests')
        .toList();

    expect(
      integrationResults,
      isNotEmpty,
    );
    expect(
      integrationResults.every(
        (result) => _hasLabel(
          result['labels'] as List<dynamic>,
          name: 'module',
          value: 'allure_flutter_test',
        ),
      ),
      isTrue,
    );
    expect(
      integrationResults.every(
        (result) => _hasLabel(
          result['labels'] as List<dynamic>,
          name: 'framework',
          value: 'flutter-integration-test',
        ),
      ),
      isTrue,
    );
  });

  testWidgets('labels integration binding tests', (tester) async {
    expect(find.text('never rendered'), findsNothing);
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
