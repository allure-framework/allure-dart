import 'dart:convert';
import 'dart:io';

import 'package:allure_dart_test/allure_dart_test.dart' as allure;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'harness_evidence.dart';

void main() {
  allure.installAllure();

  group('allure runtime plugin e2e results', () {
    test('writes passed result for plain package:test test', () async {
      final run = await _runRuntimeSample(sampleName: 'passing_sample.dart');

      await harnessStep('Verify installAllure passed result fields', () {
        expect(run.exitCode, 0, reason: run.output);
        expect(run.resultFiles, hasLength(1));

        final result = run.results.single;
        _expectRuntimeBaseResultFields(
          result,
          expectedName: 'runtime plugin passing sample',
        );
        expect(result['status'], 'passed');
        expect(result['statusDetails'], isEmpty);
        expect(result['steps'], isEmpty);
        expect(result['attachments'], isEmpty);
        expect(result['parameters'], isEmpty);
        expect(result['links'], isEmpty);
      });
    });

    test('writes failed result details for plain package:test failure',
        () async {
      final run = await _runRuntimeSample(sampleName: 'failure_sample.dart');

      await harnessStep('Verify installAllure assertion failure details', () {
        expect(run.exitCode, isNonZero,
            reason: 'sample must fail\n${run.output}');
        expect(run.resultFiles, hasLength(1));

        final result = run.results.single;
        _expectRuntimeBaseResultFields(
          result,
          expectedName: 'runtime plugin failure sample',
        );
        expect(result['status'], 'failed');
        expect(
            (result['statusDetails'] as Map<String, dynamic>)['message']
                as String,
            contains('Expected: <2>'));
        expect(
            (result['statusDetails'] as Map<String, dynamic>)['trace']
                as String,
            contains('sample_test.dart'));
      });
    });

    test('writes skipped result when test is skipped', () async {
      final run = await _runRuntimeSample(sampleName: 'skipped_sample.dart');

      await harnessStep('Verify installAllure skipped status and stage', () {
        expect(run.exitCode, 0, reason: run.output);
        expect(run.resultFiles, hasLength(1));

        final result = run.results.single;
        _expectRuntimeBaseResultFields(
          result,
          expectedName: 'runtime plugin skipped sample',
          expectedStage: 'pending',
        );
        expect(result['status'], 'skipped');
      });
    });

    test('supports nested groups and hooks with installAllure()', () async {
      final run =
          await _runRuntimeSample(sampleName: 'group_hooks_sample.dart');

      await harnessStep(
          'Verify installAllure nested group title path and passed status', () {
        expect(run.exitCode, 0, reason: run.output);
        expect(run.resultFiles, hasLength(1));

        final result = run.results.single;
        _expectRuntimeBaseResultFields(
          result,
          expectedName: 'nested test uses hooks',
          expectedTitlePath: const ['test/sample_test.dart', 'parent group'],
        );
        expect(result['status'], 'passed');
      });
    });

    test('supports package-root runtime facade calls with installAllure()',
        () async {
      final run =
          await _runRuntimeSample(sampleName: 'runtime_api_sample.dart');

      await harnessStep(
          'Verify runtime facade labels, parameters, links, steps, and attachments',
          () {
        expect(run.exitCode, 0, reason: run.output);
        expect(run.resultFiles, hasLength(1));

        final result = run.results.single;
        _expectRuntimeBaseResultFields(
          result,
          expectedName: 'runtime api sample',
        );
        expect(
          result['labels'],
          containsAll(<Map<String, String>>[
            {'name': 'owner', 'value': 'alice'},
          ]),
        );
        expect(
          result['parameters'],
          containsAll(<Map<String, String>>[
            {'name': 'browser', 'value': 'chromium'},
          ]),
        );
        expect(
          result['links'],
          containsAll(<Map<String, String>>[
            {
              'name': 'bug',
              'type': 'issue',
              'url': 'https://example.test/BUG-1',
            },
          ]),
        );

        final steps = result['steps'] as List<dynamic>;
        expect(steps, hasLength(1));
        final step = steps.single as Map<String, dynamic>;
        _expectStepFields(
          step,
          expectedName: 'outer step',
          expectedStatus: 'passed',
        );
        expect(
          step['parameters'],
          containsAll(<Map<String, String>>[
            {'name': 'attempt', 'value': '1'},
          ]),
        );
        expect(step['attachments'], isEmpty);
        final attachmentSteps =
            (step['steps'] as List<dynamic>).cast<Map<String, dynamic>>();
        expect(attachmentSteps, hasLength(1));
        final attachmentStep = attachmentSteps.single;
        _expectStepFields(
          attachmentStep,
          expectedName: 'payload',
          expectedStatus: 'passed',
        );
        final attachments = (attachmentStep['attachments'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        expect(attachments, hasLength(1));
        expect(attachments.single['name'], 'payload');
        expect(attachments.single['type'], 'application/json');
      });
    });

    test('preserves representative package:test APIs with installAllure()',
        () async {
      final run = await _runRuntimeSample(sampleName: 'api_parity_sample.dart');

      await harnessStep(
          'Verify package:test APIs remain native with installAllure', () {
        expect(run.exitCode, isNonZero,
            reason: 'sample must fail\n${run.output}');
        expect(run.resultFiles, hasLength(1));

        final result = run.results.single;
        _expectRuntimeBaseResultFields(
          result,
          expectedName: 'runtime plugin api parity sample',
        );
        expect(result['status'], 'broken');
        expect(
            (result['statusDetails'] as Map<String, dynamic>)['message']
                as String,
            contains('ignored by parity sample'));
      });
    });

    test('supports lifecycle listeners with installAllure()', () async {
      final run =
          await _runRuntimeSample(sampleName: 'listener_lifecycle_sample.dart');

      await harnessStep(
          'Verify configured lifecycle listener mutates the written result',
          () {
        expect(run.exitCode, 0, reason: run.output);
        expect(run.resultFiles, hasLength(1));

        final result = run.results.single;
        _expectRuntimeBaseResultFields(
          result,
          expectedName: 'listener lifecycle sample',
        );
        expect(
          result['labels'],
          containsAll(<Map<String, String>>[
            {'name': 'listener', 'value': 'observed'},
          ]),
        );
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

  expect(result, containsPair('statusDetails', isA<Map<String, dynamic>>()));
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

void _expectStepFields(
  Map<String, dynamic> step, {
  required String expectedName,
  required String expectedStatus,
}) {
  expect(step['name'], expectedName);
  expect(step['status'], expectedStatus);
  expect(step['stage'], 'finished');
  expect(step['statusDetails'], isA<Map<String, dynamic>>());
  expect(step['start'], isA<int>());
  expect(step['stop'], isA<int>());
}

class _RunSampleResult {
  _RunSampleResult({
    required this.exitCode,
    required this.output,
    required this.resultFiles,
    required this.results,
  });

  final int exitCode;
  final String output;
  final List<File> resultFiles;
  final List<Map<String, dynamic>> results;
}

Future<_RunSampleResult> _runRuntimeSample({required String sampleName}) async {
  final repoRoot = Directory.current;
  final commonsRoot =
      p.normalize(p.join(repoRoot.path, '..', 'allure_dart_commons'));
  const pubEnvironment = <String, String>{
    'HOME': '/tmp/codex-home',
    'DART_SUPPRESS_ANALYTICS': 'true',
  };
  final sampleSource = File(
    p.join(repoRoot.path, 'test', 'e2e', 'runtime_plugin_samples', sampleName),
  );
  final pubspecContents = '''
name: allure_dart_runtime_e2e_fixture
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
    tempPrefix: 'allure_dart_runtime_e2e_',
    sampleSource: sampleSource,
    pubspecContents: pubspecContents,
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

  final testRun = await runProcessStep(
    executable: 'dart',
    arguments: const ['test', '--reporter', 'expanded'],
    workingDirectory: project.tempDir,
    environment: <String, String>{
      ...pubEnvironment,
      'ALLURE_RESULTS_DIR': project.resultsDir.path,
    },
    producedResultsDirectory: project.resultsDir,
  );

  final output = '${testRun.stdout}\n${testRun.stderr}';

  final resultFiles = <File>[];
  final results = <Map<String, dynamic>>[];
  await harnessStep(
    'Read produced Allure result JSON files for assertions',
    () async {
      resultFiles
        ..clear()
        ..addAll(
          listProducedFiles(project.resultsDir)
              .where((file) => file.path.endsWith('-result.json')),
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
    },
  );

  return _RunSampleResult(
    exitCode: testRun.exitCode,
    output: output,
    resultFiles: resultFiles,
    results: results,
  );
}
