import 'dart:convert';
import 'dart:io';

import 'package:allure_dart_test/allure_dart_test.dart' as allure;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'harness_evidence.dart';

/// `package:test` only runs separate suites (files) concurrently; tests
/// declared inside a single suite always run sequentially. Genuine
/// concurrent Allure evidence collection is therefore exercised here with
/// two suite files executed together via `--concurrency`, each writing a
/// label, a step, and an attachment derived from its own test name.
void main() {
  allure.installAllure();

  group('allure concurrency isolation e2e results', () {
    test(
      'keeps per-suite labels, steps, and attachments isolated under concurrent suites',
      () async {
        final run = await _runConcurrentRuntimeSamples();

        await harnessStep(
          'Verify concurrently executed suites do not leak labels, steps, or attachments',
          () {
            expect(run.exitCode, 0, reason: run.output);
            expect(run.resultFiles, hasLength(2));

            final alpha = run.results.singleWhere(
              (result) =>
                  result['name'] == 'concurrency isolation sample alpha',
            );
            final beta = run.results.singleWhere(
              (result) => result['name'] == 'concurrency isolation sample beta',
            );

            _expectOwnLabelOnly(alpha, own: 'alpha', other: 'beta');
            _expectOwnLabelOnly(beta, own: 'beta', other: 'alpha');

            final alphaStep = _singleStep(alpha, expectedName: 'alpha step');
            final betaStep = _singleStep(beta, expectedName: 'beta step');

            final alphaAttachment = _singleAttachment(alphaStep);
            final betaAttachment = _singleAttachment(betaStep);
            expect(alphaAttachment['name'], 'alpha payload');
            expect(betaAttachment['name'], 'beta payload');

            final alphaContent = File(
              p.join(run.resultsDir.path, alphaAttachment['source'] as String),
            ).readAsStringSync();
            final betaContent = File(
              p.join(run.resultsDir.path, betaAttachment['source'] as String),
            ).readAsStringSync();

            expect(alphaContent, 'alpha-only-content');
            expect(betaContent, 'beta-only-content');
          },
        );
      },
    );

    test(
      'keeps concurrent setUp fixture hook globals isolated per suite',
      () async {
        final run = await _runConcurrentFixtureErrorSamples();

        await harnessStep(
          'Verify concurrent setUp failures emit both suite boom globals',
          () {
            expect(
              run.exitCode,
              isNonZero,
              reason: 'samples must fail\n${run.output}',
            );

            final messages = run.globalErrors
                .map((error) => error['message'] as String? ?? '')
                .toList();
            expect(
              messages.where(
                (message) =>
                    message.startsWith('setUp failed:') &&
                    message.contains('alpha setUp boom'),
              ),
              isNotEmpty,
              reason:
                  'missing alpha setUp global\nall errors: $messages\n'
                  '${run.output}',
            );
            expect(
              messages.where(
                (message) =>
                    message.startsWith('setUp failed:') &&
                    message.contains('beta setUp boom'),
              ),
              isNotEmpty,
              reason:
                  'missing beta setUp global\nall errors: $messages\n'
                  '${run.output}',
            );
          },
        );
      },
    );
  });
}

void _expectOwnLabelOnly(
  Map<String, dynamic> result, {
  required String own,
  required String other,
}) {
  final labels = (result['labels'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final sampleLabelValues = labels
      .where((label) => label['name'] == 'sample')
      .map((label) => label['value'])
      .toList();
  expect(sampleLabelValues, [own]);
  expect(sampleLabelValues, isNot(contains(other)));
}

Map<String, dynamic> _singleStep(
  Map<String, dynamic> result, {
  required String expectedName,
}) {
  final steps = (result['steps'] as List<dynamic>).cast<Map<String, dynamic>>();
  expect(steps, hasLength(1));
  final step = steps.single;
  expect(step['name'], expectedName);
  expect(step['status'], 'passed');
  return step;
}

Map<String, dynamic> _singleAttachment(Map<String, dynamic> step) {
  final attachmentSteps = (step['steps'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  expect(attachmentSteps, hasLength(1));
  final attachments = (attachmentSteps.single['attachments'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  expect(attachments, hasLength(1));
  return attachments.single;
}

class _RunSampleResult {
  _RunSampleResult({
    required this.exitCode,
    required this.output,
    required this.resultsDir,
    required this.producedFiles,
    required this.resultFiles,
    required this.results,
    required this.globalErrors,
  });

  final int exitCode;
  final String output;
  final Directory resultsDir;
  final List<File> producedFiles;
  final List<File> resultFiles;
  final List<Map<String, dynamic>> results;
  final List<Map<String, dynamic>> globalErrors;
}

Future<_RunSampleResult> _runConcurrentRuntimeSamples() {
  return _runConcurrentSamples(
    tempPrefix: 'allure_dart_concurrency_e2e_',
    primarySampleName: 'alpha_sample.dart',
    secondarySampleName: 'beta_sample.dart',
    secondaryTestFileName: 'beta_concurrency_test.dart',
  );
}

Future<_RunSampleResult> _runConcurrentFixtureErrorSamples() {
  return _runConcurrentSamples(
    tempPrefix: 'allure_dart_concurrency_fixture_error_e2e_',
    primarySampleName: 'fixture_error_concurrent_alpha_sample.dart',
    secondarySampleName: 'fixture_error_concurrent_beta_sample.dart',
    secondaryTestFileName: 'beta_concurrency_test.dart',
  );
}

Future<_RunSampleResult> _runConcurrentSamples({
  required String tempPrefix,
  required String primarySampleName,
  required String secondarySampleName,
  required String secondaryTestFileName,
}) async {
  final repoRoot = Directory.current;
  final commonsRoot = p.normalize(
    p.join(repoRoot.path, '..', 'allure_dart_commons'),
  );
  const pubEnvironment = <String, String>{
    'HOME': '/tmp/codex-home',
    'DART_SUPPRESS_ANALYTICS': 'true',
  };
  final samplesDir = Directory(
    p.join(repoRoot.path, 'test', 'e2e', 'concurrency_samples'),
  );
  final pubspecContents =
      '''
name: allure_dart_concurrency_e2e_fixture
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
    tempPrefix: tempPrefix,
    sampleSource: File(p.join(samplesDir.path, primarySampleName)),
    additionalSampleSources: <String, File>{
      secondaryTestFileName: File(p.join(samplesDir.path, secondarySampleName)),
    },
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
    arguments: const ['test', '--reporter', 'expanded', '--concurrency=4'],
    workingDirectory: project.tempDir,
    environment: <String, String>{
      ...pubEnvironment,
      'ALLURE_RESULTS_DIR': project.resultsDir.path,
    },
    producedResultsDirectory: project.resultsDir,
  );

  final output = '${testRun.stdout}\n${testRun.stderr}';

  final producedFiles = <File>[];
  final resultFiles = <File>[];
  final results = <Map<String, dynamic>>[];
  final globalErrors = <Map<String, dynamic>>[];
  await harnessStep(
    'Read produced Allure result and globals JSON files for assertions',
    () async {
      producedFiles
        ..clear()
        ..addAll(listProducedFiles(project.resultsDir));
      resultFiles
        ..clear()
        ..addAll(
          producedFiles.where((file) => file.path.endsWith('-result.json')),
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
      globalErrors
        ..clear()
        ..addAll(
          producedFiles
              .where((file) => file.path.endsWith('-globals.json'))
              .expand((file) {
                final globals =
                    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
                return (globals['errors'] as List<dynamic>? ?? const [])
                    .cast<Map<String, dynamic>>();
              }),
        );
    },
  );

  return _RunSampleResult(
    exitCode: testRun.exitCode,
    output: output,
    resultsDir: project.resultsDir,
    producedFiles: producedFiles,
    resultFiles: resultFiles,
    results: results,
    globalErrors: globalErrors,
  );
}
