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
    expect(integrationResults.every(_hasSteps), isTrue);

    // Regression guard: `fullName` must point at the user test file
    // (`integration_binding_smoke_test.dart`) and never at the adapter's own
    // `integration_test.dart` wrapper, even though that wrapper sits on the
    // stack above `flutter_test_drop_in.dart` for host-run integration
    // tests.
    expect(
      integrationResults.every(
        (result) =>
            (result['fullName'] as String?)
                ?.contains('integration_binding_smoke_test.dart') ??
            false,
      ),
      isTrue,
    );
    expect(
      integrationResults.any(
        (result) =>
            (result['fullName'] as String?)
                ?.contains('integration_test.dart') ??
            false,
      ),
      isFalse,
    );
    expect(
      integrationResults.every(
        (result) => _hasLabel(
          result['labels'] as List<dynamic>,
          name: 'package',
          value: 'test/integration_binding_smoke_test.dart',
        ),
      ),
      isTrue,
    );
    expect(
      integrationResults.any(
        (result) => (result['labels'] as List<dynamic>).any(
          (label) =>
              label is Map &&
              <Object?>['suite', 'parentSuite', 'subSuite', 'package']
                  .contains(label['name']?.toString()) &&
              (label['value']?.toString().contains('integration_test.dart') ??
                  false),
        ),
      ),
      isFalse,
    );
  });

  testWidgets('labels integration binding tests', (tester) async {
    await step('verify integration binding finder', (_) async {
      expect(find.text('never rendered'), findsNothing);
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
