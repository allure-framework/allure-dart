import 'dart:convert';
import 'dart:io';

import 'package:allure_dart_test/allure_dart_test.dart' as allure;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'harness_evidence.dart';

void main() {
  allure.installAllure();

  group('allure drop-in test import e2e results', () {
    test('writes passed result for drop-in import', () async {
      final run = await _runDropInSample(sampleName: 'passing_sample.dart');

      await harnessStep('Verify passed drop-in result fields', () {
        expect(run.exitCode, 0, reason: run.output);
        expect(run.resultFiles, hasLength(1));

        final result = run.results.single;
        _expectRuntimeBaseResultFields(
          result,
          expectedName: 'drop in passing sample',
        );
        expect(result['status'], 'passed');
        expect(result['statusDetails'], isEmpty);
      });
    });

    test('writes failed result details for drop-in import', () async {
      final run = await _runDropInSample(sampleName: 'failure_sample.dart');

      await harnessStep('Verify drop-in assertion failure details', () {
        expect(run.exitCode, isNonZero,
            reason: 'sample must fail\n${run.output}');
        expect(run.resultFiles, hasLength(1));

        final result = run.results.single;
        _expectRuntimeBaseResultFields(
          result,
          expectedName: 'drop in failure sample',
        );
        expect(result['status'], 'failed');
        expect(
          (result['statusDetails'] as Map<String, dynamic>)['message']
              as String,
          contains('Expected: <3>'),
        );
        expect(
          (result['statusDetails'] as Map<String, dynamic>)['trace'] as String,
          contains('sample_test.dart'),
        );
      });
    });

    test('writes skipped result for drop-in import', () async {
      final run = await _runDropInSample(sampleName: 'skipped_sample.dart');

      await harnessStep('Verify drop-in skipped status and pending stage', () {
        expect(run.exitCode, 0, reason: run.output);
        expect(run.resultFiles, hasLength(1));

        final result = run.results.single;
        _expectRuntimeBaseResultFields(
          result,
          expectedName: 'drop in skipped sample',
          expectedStage: 'pending',
        );
        expect(result['status'], 'skipped');
      });
    });

    test('supports nested groups and hooks through drop-in import', () async {
      final run = await _runDropInSample(sampleName: 'group_hooks_sample.dart');

      await harnessStep('Verify drop-in group title path and hook containers',
          () {
        expect(run.exitCode, 0, reason: run.output);
        expect(run.resultFiles, hasLength(1));

        final result = run.results.single;
        _expectRuntimeBaseResultFields(
          result,
          expectedName: 'nested test uses hooks',
          expectedTitlePath: const ['test/sample_test.dart', 'parent group'],
        );
        expect(result['status'], 'passed');
        expect(run.containerFiles, isNotEmpty);
        final flattenedFixtures = run.containers
            .map((container) => <dynamic>[
                  ...(container['befores'] as List<dynamic>),
                  ...(container['afters'] as List<dynamic>),
                ])
            .expand((fixtures) => fixtures);
        expect(
          flattenedFixtures.any((fixture) => fixture['name'] == 'setUp'),
          isTrue,
        );
        expect(
          flattenedFixtures.any((fixture) => fixture['name'] == 'tearDown'),
          isTrue,
        );
        expect(
          flattenedFixtures.any((fixture) => fixture['name'] == 'setUpAll'),
          isTrue,
        );
        expect(
          flattenedFixtures.any((fixture) => fixture['name'] == 'tearDownAll'),
          isTrue,
        );
        for (final container in run.containers) {
          final children =
              (container['children'] as List<dynamic>).cast<String>().toList();
          expect(children.toSet().length, children.length);
        }
      });
    });

    test('preserves representative package:test APIs unchanged', () async {
      final run = await _runDropInSample(sampleName: 'api_parity_sample.dart');

      await harnessStep(
          'Verify representative package:test APIs still behave natively', () {
        expect(run.exitCode, isNonZero,
            reason: 'sample must fail\n${run.output}');
        expect(run.resultFiles, hasLength(1));

        final result = run.results.single;
        _expectRuntimeBaseResultFields(
          result,
          expectedName: 'drop in api parity sample',
        );
        expect(result['status'], 'broken');
        expect(
          (result['statusDetails'] as Map<String, dynamic>)['message']
              as String,
          contains('ignored by parity sample'),
        );
      });
    });

    test('does not duplicate hooks when combined with installAllure()',
        () async {
      final run = await _runSampleFromDirectory(
        sampleDirectory: 'mixed_mode_samples',
        sampleName: 'install_plus_drop_in_sample.dart',
      );

      await harnessStep(
          'Verify combined installAllure and drop-in import writes one result',
          () {
        expect(run.exitCode, 0, reason: run.output);
        expect(run.resultFiles, hasLength(1));

        final result = run.results.single;
        _expectRuntimeBaseResultFields(
          result,
          expectedName: 'install plus drop in sample',
        );
        expect(result['status'], 'passed');
      });
    });

    test('propagates before fixture metadata and keeps after metadata local',
        () async {
      final run = await _runDropInSample(
        sampleName: 'fixture_metadata_sample.dart',
      );

      await harnessStep(
          'Verify before fixture metadata reaches the test and after metadata stays on the fixture',
          () {
        expect(run.exitCode, 0, reason: run.output);
        expect(run.resultFiles, hasLength(1));

        final result = run.results.single;
        _expectRuntimeBaseResultFields(
          result,
          expectedName: 'fixture metadata sample',
        );
        expect(
          result['labels'],
          containsAll(<Map<String, String>>[
            {'name': 'owner', 'value': 'setup-owner'},
          ]),
        );
        expect(
          result['parameters'],
          containsAll(<Map<String, String>>[
            {'name': 'setup-param', 'value': 'before'},
          ]),
        );
        expect(
          result['parameters'],
          isNot(
            contains(<String, String>{
              'name': 'teardown-param',
              'value': 'after',
            }),
          ),
        );

        final afterFixtures = run.containers
            .expand((container) => container['afters'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .toList();
        expect(afterFixtures, isNotEmpty);
        expect(
          afterFixtures,
          contains(
            containsPair(
              'description',
              'after fixture description',
            ),
          ),
        );
        expect(
          afterFixtures
              .expand((fixture) => fixture['parameters'] as List<dynamic>),
          contains(
            predicate<Map<dynamic, dynamic>>(
              (parameter) =>
                  parameter['name'] == 'teardown-param' &&
                  parameter['value'] == 'after',
            ),
          ),
        );
      });
    });

    test('skips test-plan excluded tests before the body runs', () async {
      final run = await _runDropInSample(
        sampleName: 'test_plan_sample.dart',
        testPlanContents:
            '{"tests":[{"selector":"test/sample_test.dart#selected elsewhere"}]}',
      );

      await harnessStep(
          'Verify test-plan excluded drop-in test does not write a result', () {
        expect(run.exitCode, 0, reason: run.output);
        expect(run.resultFiles, isEmpty);
      });
    });
  });
}

void _expectRuntimeBaseResultFields(
  Map<String, dynamic> result, {
  required String expectedName,
  String expectedStage = 'finished',
  List<String>? expectedTitlePath,
}) {
  expect(result['uuid'], allOf(isA<String>(), isNotEmpty));
  expect(result['historyId'], allOf(isA<String>(), isNotEmpty));
  expect(result['testCaseId'], allOf(isA<String>(), isNotEmpty));
  expect(result['testCaseName'], allOf(isA<String>(), isNotEmpty));
  expect(result['name'], expectedName);
  expect(result['fullName'], startsWith('test/sample_test.dart#'));
  expect(result['fullName'], contains(expectedName));
  expect(result['status'], allOf(isA<String>(), isNotEmpty));
  expect(result['stage'], expectedStage);
  expect(result['start'], isA<int>());
  expect(result['stop'], isA<int>());
  expect((result['stop'] as int) >= (result['start'] as int), isTrue);
  expect(
    result['titlePath'],
    expectedTitlePath ?? <String>['test/sample_test.dart'],
  );

  expect(
    result,
    containsPair('statusDetails', isA<Map<String, dynamic>>()),
  );
  expect(result['steps'], isA<List<dynamic>>());
  expect(result['attachments'], isA<List<dynamic>>());
  expect(result['parameters'], isA<List<dynamic>>());
  expect(result['labels'], isA<List<dynamic>>());
  expect(result['links'], isA<List<dynamic>>());

  final labels = result['labels'] as List<dynamic>;
  expect(
      labels,
      containsAll(<Map<String, String>>[
        {'name': 'framework', 'value': 'dart-test'},
        {'name': 'language', 'value': 'dart'},
        {'name': 'package', 'value': 'test/sample_test.dart'},
        {'name': 'testMethod', 'value': expectedName},
      ]));
}

class _RunSampleResult {
  _RunSampleResult({
    required this.exitCode,
    required this.output,
    required this.resultFiles,
    required this.results,
    required this.containerFiles,
    required this.containers,
  });

  final int exitCode;
  final String output;
  final List<File> resultFiles;
  final List<Map<String, dynamic>> results;
  final List<File> containerFiles;
  final List<Map<String, dynamic>> containers;
}

Future<_RunSampleResult> _runDropInSample({
  required String sampleName,
  String? testPlanContents,
}) {
  return _runSampleFromDirectory(
    sampleDirectory: 'drop_in_samples',
    sampleName: sampleName,
    testPlanContents: testPlanContents,
  );
}

Future<_RunSampleResult> _runSampleFromDirectory({
  required String sampleDirectory,
  required String sampleName,
  String? testPlanContents,
}) async {
  final repoRoot = Directory.current;
  final commonsRoot =
      p.normalize(p.join(repoRoot.path, '..', 'allure_dart_commons'));
  const pubEnvironment = <String, String>{
    'HOME': '/tmp/codex-home',
    'DART_SUPPRESS_ANALYTICS': 'true',
  };

  final sampleSource = File(
    p.join(repoRoot.path, 'test', 'e2e', sampleDirectory, sampleName),
  );
  final pubspecContents = '''
name: allure_dart_drop_in_e2e_fixture
publish_to: none

environment:
  sdk: ^3.6.0

dependencies:
  allure_dart_test:
    path: ${repoRoot.path}

dependency_overrides:
  allure_dart_commons:
    path: $commonsRoot

dev_dependencies:
  test: ^1.25.0
  test_api: ^0.7.0
''';

  final project = await prepareTestProject(
    tempPrefix: 'allure_dart_drop_in_e2e_',
    sampleSource: sampleSource,
    pubspecContents: pubspecContents,
    testPlanContents: testPlanContents,
  );
  addTearDown(() async {
    if (project.tempDir.existsSync()) {
      await project.tempDir.delete(recursive: true);
    }
  });

  final pubGet = await runProcessStep(
    executable: 'dart',
    arguments: const ['pub', 'get'],
    workingDirectory: project.tempDir,
    environment: pubEnvironment,
  );

  if (pubGet.exitCode != 0) {
    fail('dart pub get failed:\n${pubGet.stdout}\n${pubGet.stderr}');
  }

  final environment = <String, String>{
    ...pubEnvironment,
    'ALLURE_RESULTS_DIR': project.resultsDir.path,
  };
  if (project.testPlanFile != null) {
    environment['ALLURE_TESTPLAN_PATH'] = project.testPlanFile!.path;
  }

  final testRun = await runProcessStep(
    executable: 'dart',
    arguments: const ['test', '--reporter', 'expanded'],
    workingDirectory: project.tempDir,
    environment: environment,
    producedResultsDirectory: project.resultsDir,
  );

  final output = '${testRun.stdout}\n${testRun.stderr}';

  final resultFiles = <File>[];
  final containerFiles = <File>[];
  final results = <Map<String, dynamic>>[];
  final containers = <Map<String, dynamic>>[];
  await harnessStep(
    'Read produced Allure result and container JSON files for assertions',
    () async {
      final files = listProducedFiles(project.resultsDir);
      resultFiles
        ..clear()
        ..addAll(
          files.where((file) => file.path.endsWith('-result.json')),
        )
        ..sort((a, b) => a.path.compareTo(b.path));
      containerFiles
        ..clear()
        ..addAll(
          files.where((file) => file.path.endsWith('-container.json')),
        )
        ..sort((a, b) => a.path.compareTo(b.path));
      results
        ..clear()
        ..addAll(
          resultFiles.map(
            (file) =>
                jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
          ),
        );
      containers
        ..clear()
        ..addAll(
          containerFiles.map(
            (file) =>
                jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
          ),
        );
    },
  );

  return _RunSampleResult(
    exitCode: testRun.exitCode,
    output: output,
    resultFiles: resultFiles,
    results: results,
    containerFiles: containerFiles,
    containers: containers,
  );
}
