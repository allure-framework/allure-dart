import 'dart:io';

// Import the framework-agnostic Allure APIs when integrating a custom runner.
import 'package:allure_dart_commons/allure_dart_commons.dart';

Future<void> main() async {
  final resultsDirectory = await Directory.systemTemp.createTemp(
    'allure-dart-commons-example-',
  );
  final lifecycle = AllureLifecycle(
    writer: AllureResultsWriter(outputDirectory: resultsDirectory.path),
  );

  final testUuid = lifecycle.startTest(
    name: 'framework agnostic example',
    labels: const <AllureLabel>[
      AllureLabel(name: 'framework', value: 'custom'),
    ],
  );

  await lifecycle.runStep(testUuid, 'verify arithmetic', () {
    final answer = 40 + 2;
    if (answer != 42) {
      throw StateError('Expected 42, got $answer');
    }
  });

  await lifecycle.addTextAttachment(
    testUuid: testUuid,
    name: 'calculation',
    type: 'text/plain',
    content: '40 + 2 = 42',
  );

  await lifecycle.stopTest(testUuid, status: AllureStatus.passed);
  await lifecycle.writeTest(testUuid);

  stdout.writeln('Allure results written to ${resultsDirectory.path}');
}
