import 'dart:convert';
import 'dart:io';

import 'package:allure_flutter_test/integration_test.dart';

void main() {
  final resultsDir = Directory.systemTemp.createTempSync(
    'allure_flutter_integration_',
  );

  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  installAllure(
    lifecycle: AllureLifecycle(
      writer: AllureResultsWriter(outputDirectory: resultsDir.path),
    ),
  );

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

    expect(
      results.every(
        (result) => _hasLabel(
          result['labels'] as List<dynamic>,
          name: 'framework',
          value: 'flutter-integration-test',
        ),
      ),
      isTrue,
    );

    await resultsDir.delete(recursive: true);
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
