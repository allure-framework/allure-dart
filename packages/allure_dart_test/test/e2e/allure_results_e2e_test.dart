import 'dart:convert';
import 'dart:io';

import 'package:allure_dart_test/allure_dart_test.dart' as allure;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'harness_evidence.dart';

void main() {
  allure.installAllure();

  group('allure e2e results', () {
    test('writes core test-result fields', () async {
      final run = await _runSample(sampleName: 'core_fields_sample.dart');

      await harnessStep('Verify core passed test result fields', () {
        expect(run.exitCode, 0, reason: run.output);
        expect(run.resultFiles, hasLength(1));

        final result = run.results.single;
        _expectBaseResultFields(result, expectedName: 'core fields sample');
        expect(result['status'], 'passed');
        expect(result['statusDetails'], isEmpty);
        expect(result['steps'], isEmpty);
        expect(result['attachments'], isEmpty);
        expect(result['parameters'], isEmpty);
        expect(
            result['labels'],
            containsAll(<Map<String, String>>[
              {'name': 'framework', 'value': 'dart-test'},
              {'name': 'language', 'value': 'dart'},
            ]));
        expect(result['links'], isEmpty);
      });
    });

    test('writes labels, parameters and links', () async {
      final run = await _runSample(sampleName: 'metadata_sample.dart');

      await harnessStep('Verify labels, parameters, and links', () {
        expect(run.exitCode, 0, reason: run.output);
        final result = run.results.single;
        _expectBaseResultFields(result, expectedName: 'metadata sample');

        expect(
            result['labels'],
            containsAll(<Map<String, String>>[
              {'name': 'framework', 'value': 'dart-test'},
              {'name': 'language', 'value': 'dart'},
            ]));
        expect(result['parameters'], [
          {'name': 'browser', 'value': 'chromium'},
        ]);
        expect(result['links'], [
          {
            'name': 'docs',
            'type': 'custom',
            'url': 'https://example.test/docs',
          },
        ]);
      });
    });

    test('writes nested steps and step fields', () async {
      final run = await _runSample(sampleName: 'step_sample.dart');

      await harnessStep('Verify nested step tree and step fields', () {
        expect(run.exitCode, 0, reason: run.output);
        final result = run.results.single;
        _expectBaseResultFields(result, expectedName: 'step sample');

        final steps = result['steps'] as List<dynamic>;
        expect(steps, hasLength(1));

        final outer = steps.single as Map<String, dynamic>;
        _expectStepFields(outer,
            expectedName: 'outer step', expectedStatus: 'passed');

        final nested = outer['steps'] as List<dynamic>;
        expect(nested, hasLength(1));
        _expectStepFields(
          nested.single as Map<String, dynamic>,
          expectedName: 'inner step',
          expectedStatus: 'passed',
        );
      });
    });

    test('writes binary attachment at test level', () async {
      final run = await _runSample(sampleName: 'binary_attachment_sample.dart');

      await harnessStep('Verify binary test-level attachment payload', () {
        expect(run.exitCode, 0, reason: run.output);
        final result = run.results.single;
        _expectBaseResultFields(result,
            expectedName: 'binary attachment sample');

        expect(result['attachments'], isEmpty);
        final attachment = _expectAttachmentStep(
          result,
          expectedName: 'bytes',
          expectedType: 'application/octet-stream',
          sourceMatcher: allOf(isNotEmpty, endsWith('.bin')),
        );

        final content = File(
          p.join(run.resultsDir.path, attachment['source'] as String),
        ).readAsStringSync();
        expect(content, 'hello-bytes');
      });
    });

    test('writes text attachment inside step', () async {
      final run = await _runSample(sampleName: 'text_attachment_sample.dart');

      await harnessStep('Verify text attachment nested inside a step', () {
        expect(run.exitCode, 0, reason: run.output);
        final result = run.results.single;
        _expectBaseResultFields(result, expectedName: 'text attachment sample');

        final steps = result['steps'] as List<dynamic>;
        expect(steps, hasLength(1));

        final step = steps.single as Map<String, dynamic>;
        _expectStepFields(
          step,
          expectedName: 'step with text attachment',
          expectedStatus: 'passed',
        );

        expect(step['attachments'], isEmpty);
        final attachment = _expectAttachmentStep(
          step,
          expectedName: 'payload',
          expectedType: 'application/json',
          sourceMatcher: endsWith('.json'),
        );

        final content = File(
          p.join(run.resultsDir.path, attachment['source'] as String),
        ).readAsStringSync();
        expect(content, '{"status":"ok"}');
      });
    });

    test('writes failure details without synthetic test-level error attachment',
        () async {
      final run = await _runSample(sampleName: 'failure_sample.dart');

      await harnessStep(
          'Verify assertion failure status and absence of synthetic attachment',
          () {
        expect(run.exitCode, isNonZero,
            reason: 'sample must fail\n${run.output}');
        final result = run.results.single;
        _expectBaseResultFields(result, expectedName: 'failure sample');

        expect(result['status'], 'failed');
        expect(
            (result['statusDetails'] as Map<String, dynamic>)['message']
                as String,
            contains('Expected: <2>'));
        expect(
            (result['statusDetails'] as Map<String, dynamic>)['trace']
                as String,
            contains('sample_test.dart'));

        final steps = result['steps'] as List<dynamic>;
        expect(steps, hasLength(1));
        final step = steps.single as Map<String, dynamic>;
        _expectStepFields(step,
            expectedName: 'failing step', expectedStatus: 'failed');
        expect(
            (step['statusDetails'] as Map<String, dynamic>)['message']
                as String,
            contains('Expected: <2>'));

        expect(step['attachments'], isEmpty);
        _expectAttachmentStep(
          step,
          expectedName: 'pre-failure context',
          expectedType: 'text/plain',
          sourceMatcher: endsWith('.txt'),
        );

        final testAttachments = result['attachments'] as List<dynamic>;
        expect(testAttachments, isEmpty);
      });
    });

    test('keeps duplicate allureTest names unique across groups', () async {
      final run = await _runSample(sampleName: 'duplicate_name_sample.dart');

      await harnessStep(
          'Verify duplicate display names keep distinct full names and IDs',
          () {
        expect(run.exitCode, 0, reason: run.output);
        expect(run.resultFiles, hasLength(2));

        final fullNames =
            run.results.map((result) => result['fullName'] as String).toSet();
        final testCaseIds =
            run.results.map((result) => result['testCaseId'] as String).toSet();

        expect(
          fullNames,
          {
            'test/sample_test.dart#alpha#shared name',
            'test/sample_test.dart#beta#shared name',
          },
        );
        expect(testCaseIds, hasLength(2));
      });
    });

    test('writes extended metadata and classification fields', () async {
      final run = await _runSample(sampleName: 'extended_metadata_sample.dart');

      await harnessStep(
          'Verify display name, test case name, and classification details',
          () {
        expect(run.exitCode, 0, reason: run.output);
        expect(run.resultFiles, hasLength(1));

        final result = run.results.single;
        _expectBaseResultFields(
          result,
          expectedName: 'Readable extended metadata',
          expectedFullNameContains: 'extended metadata sample',
          expectedTestMethod: 'extended metadata sample',
        );
        expect(result['testCaseName'], 'logical extended metadata');
        expect(result['statusDetails'], containsPair('known', true));
        expect(result['statusDetails'], containsPair('muted', false));
        expect(result['statusDetails'], containsPair('flaky', true));
        expect(result['statusDetails'], containsPair('actual', 'actual-value'));
        expect(
          result['statusDetails'],
          containsPair('expected', 'expected-value'),
        );
      });
    });

    test('writes prepared and stream attachment payloads', () async {
      final run = await _runSample(
          sampleName: 'prepared_stream_attachment_sample.dart');

      await harnessStep(
          'Verify prepared and stream attachments preserve original payloads',
          () {
        expect(run.exitCode, 0, reason: run.output);
        expect(run.resultFiles, hasLength(1));

        final result = run.results.single;
        _expectBaseResultFields(
          result,
          expectedName: 'prepared stream attachment sample',
        );
        expect(result['attachments'], isEmpty);
        final attachmentSteps =
            (result['steps'] as List<dynamic>).cast<Map<String, dynamic>>();
        expect(attachmentSteps, hasLength(2));

        final contents = <String, String>{};
        for (final attachmentStep in attachmentSteps) {
          _expectStepFields(
            attachmentStep,
            expectedName: attachmentStep['name'] as String,
            expectedStatus: 'passed',
          );
          final attachments = (attachmentStep['attachments'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
          expect(attachments, hasLength(1));
          final attachment = attachments.single;
          expect(attachment['name'], attachmentStep['name']);
          contents[attachmentStep['name'] as String] = File(
            p.join(run.resultsDir.path, attachment['source'] as String),
          ).readAsStringSync();
        }
        expect(contents['prepared evidence'], 'prepared evidence payload');
        expect(contents['stream evidence'], 'stream evidence payload');
      });
    });

    test('skips allureTest excluded by test plan before the body runs',
        () async {
      final run = await _runSample(
        sampleName: 'allure_test_plan_sample.dart',
        testPlanContents:
            '{"tests":[{"selector":"test/sample_test.dart#selected elsewhere"}]}',
      );

      await harnessStep(
          'Verify test-plan excluded allureTest body did not write a result',
          () {
        expect(run.exitCode, 0, reason: run.output);
        expect(run.resultFiles, isEmpty);
        expect(run.output, contains('Excluded by Allure test plan'));
        expect(run.output, isNot(contains('body should not run')));
      });
    });
  });
}

void _expectBaseResultFields(
  Map<String, dynamic> result, {
  required String expectedName,
  String? expectedFullNameContains,
  String? expectedTestMethod,
}) {
  expect(result['uuid'], allOf(isA<String>(), isNotEmpty));
  expect(result['historyId'], allOf(isA<String>(), isNotEmpty));
  expect(result['testCaseId'], allOf(isA<String>(), isNotEmpty));
  expect(result['testCaseName'], allOf(isA<String>(), isNotEmpty));
  expect(result['name'], expectedName);
  expect(result['fullName'], startsWith('test/sample_test.dart#'));
  expect(
      result['fullName'], contains(expectedFullNameContains ?? expectedName));
  expect(result['status'], allOf(isA<String>(), isNotEmpty));
  expect(result['stage'], 'finished');
  expect(result['start'], isA<int>());
  expect(result['stop'], isA<int>());
  expect((result['stop'] as int) >= (result['start'] as int), isTrue);
  expect(result['titlePath'], <String>['test/sample_test.dart']);

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
        {'name': 'testMethod', 'value': expectedTestMethod ?? expectedName},
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
  expect(step['start'], isA<int>());
  expect(step['stop'], isA<int>());
  expect((step['stop'] as int) >= (step['start'] as int), isTrue);
  expect(step, containsPair('statusDetails', isA<Map<String, dynamic>>()));
  expect(step['steps'], isA<List<dynamic>>());
  expect(step['attachments'], isA<List<dynamic>>());
  expect(step['parameters'], isA<List<dynamic>>());
}

Map<String, dynamic> _expectAttachmentStep(
  Map<String, dynamic> executable, {
  required String expectedName,
  required String expectedType,
  required Matcher sourceMatcher,
}) {
  final steps =
      (executable['steps'] as List<dynamic>).cast<Map<String, dynamic>>();
  expect(steps, hasLength(1));
  final attachmentStep = steps.single;
  _expectStepFields(
    attachmentStep,
    expectedName: expectedName,
    expectedStatus: 'passed',
  );

  final attachments = (attachmentStep['attachments'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  expect(attachments, hasLength(1));
  final attachment = attachments.single;
  expect(attachment['name'], expectedName);
  expect(attachment['type'], expectedType);
  expect(attachment['source'], sourceMatcher);
  return attachment;
}

class _RunSampleResult {
  _RunSampleResult({
    required this.exitCode,
    required this.output,
    required this.resultsDir,
    required this.resultFiles,
    required this.results,
  });

  final int exitCode;
  final String output;
  final Directory resultsDir;
  final List<File> resultFiles;
  final List<Map<String, dynamic>> results;
}

Future<_RunSampleResult> _runSample({
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
  final sampleSource =
      File(p.join(repoRoot.path, 'test', 'e2e', 'samples', sampleName));
  final pubspecContents = '''
name: allure_dart_e2e_fixture
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
''';

  final project = await prepareTestProject(
    tempPrefix: 'allure_dart_e2e_',
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
    resultsDir: project.resultsDir,
    resultFiles: resultFiles,
    results: results,
  );
}
