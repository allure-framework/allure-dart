/// Subprocess e2e coverage for the Flutter Allure adapter.
///
/// Modeled on `packages/allure_dart_test/test/e2e/harness_evidence.dart` and
/// its consumers, simplified for this package: each test here shells out to
/// `flutter test <sample(s)>` against fixtures in `test/samples/`, pointing
/// `ALLURE_RESULTS_DIR` at a unique temporary directory per run so a
/// subprocess run never writes into (or races with) the package's default
/// `allure-results` directory used by the smoke tests in this same `flutter
/// test test` invocation.
///
/// This harness file itself uses the Flutter Allure drop-in import so its
/// own assertions are modeled as Allure results/steps for agent-mode review
/// of the harness run, not just the sampled subprocess runs.
import 'dart:convert';
import 'dart:io';

import 'package:allure_flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  // This file only declares plain `test()` cases (no `testWidgets()`), and
  // `testWidgets()` is what normally initializes `TestWidgetsFlutterBinding`
  // as a side effect of being declared. The Allure drop-in `test()` wrapper
  // resolves the `flutter-test` framework label via `WidgetsBinding.instance`
  // while scheduling each test, so the binding must be initialized explicitly
  // up front here.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('flutter adapter e2e', () {
    test('reports a failed status for a failing testWidgets sample', () async {
      final run = await _runFlutterSample('failing_widget_sample.dart');

      await step('Verify failed status and message', (_) async {
        expect(run.exitCode, isNot(0), reason: run.output);
        expect(run.resultFiles, hasLength(1));

        final result = run.results.single;
        expect(result['name'], 'intentionally fails');
        expect(result['status'], 'failed');
        expect(
          (result['statusDetails'] as Map<String, dynamic>)['message']
              as String,
          contains('Test failed'),
        );
      });
    });

    test('captures an attachment payload written from a testWidgets sample',
        () async {
      final run = await _runFlutterSample('attachment_widget_sample.dart');

      await step('Verify attachment payload evidence', (_) async {
        expect(run.exitCode, 0, reason: run.output);
        expect(run.resultFiles, hasLength(1));

        final result = run.results.single;
        expect(result['name'], 'records an attachment payload');
        expect(result['status'], 'passed');

        final steps =
            (result['steps'] as List<dynamic>).cast<Map<String, dynamic>>();
        expect(steps, hasLength(1));
        final attachmentSteps = (steps.single['steps'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        expect(attachmentSteps, hasLength(1));
        final attachments =
            (attachmentSteps.single['attachments'] as List<dynamic>)
                .cast<Map<String, dynamic>>();
        expect(attachments, hasLength(1));
        final attachment = attachments.single;
        expect(attachment['name'], 'widget payload');
        expect(attachment['type'], 'text/plain');

        final attachmentContent = File(
          p.join(run.resultsDir.path, attachment['source'] as String),
        ).readAsStringSync();
        expect(attachmentContent, 'flutter-widget-attachment-content');
      });
    });

    test(
        'writes a result only for the testWidgets selected by an Allure test plan',
        () async {
      final run = await _runFlutterSample(
        'test_plan_widget_sample.dart',
        testPlanSelector:
            'test/samples/test_plan_widget_sample.dart#selected by test plan',
      );

      await step('Verify test-plan selection excludes the other testWidgets',
          (_) async {
        expect(run.exitCode, 0, reason: run.output);
        expect(run.resultFiles, hasLength(1));

        final result = run.results.single;
        expect(result['name'], 'selected by test plan');
        expect(result['status'], 'passed');
        // The excluded test still shows up as a runner-level skip in the
        // console output, but its Allure declaration skip means it never
        // reaches the lifecycle and therefore writes no result file.
        expect(run.output, contains('excluded by test plan'));
        expect(
          run.results
              .any((result) => result['name'] == 'excluded by test plan'),
          isFalse,
        );
      });
    });

    test(
        'writes no Allure result for a declaration-skipped testWidgets with plain installAllure()',
        () async {
      final run = await _runFlutterSample(
        'install_allure_declaration_skip_sample.dart',
      );

      await step(
          'Verify installAllure + original imports + declaration skip writes zero results',
          (_) async {
        expect(run.exitCode, 0, reason: run.output);
        expect(run.resultFiles, isEmpty);
      });
    });

    test(
        'supports nested groups and all fixture hooks through the Flutter drop-in import',
        () async {
      final run = await _runFlutterSample('group_hooks_widget_sample.dart');

      await step('Verify group hook containers cover all four fixture types',
          (_) async {
        expect(run.exitCode, 0, reason: run.output);
        expect(run.resultFiles, hasLength(1));

        final result = run.results.single;
        expect(result['name'], 'nested testWidgets uses hooks');
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
      });
    });

    test(
        'writes a skipped result for a testWidgets nested in a skipped group, and still runs the group setUp fixture',
        () async {
      final run = await _runFlutterSample('group_skip_widget_sample.dart');

      await step(
          'Verify a group-level skip still schedules and skips the nested testWidgets, while the setUp fixture tradeoff still runs',
          (_) async {
        expect(run.exitCode, 0, reason: run.output);
        expect(run.resultFiles, hasLength(1));

        final result = run.results.single;
        expect(result['name'], 'nested testWidgets in skipped group');
        expect(result['status'], 'skipped');
        expect(result['stage'], 'pending');

        expect(run.containerFiles, isNotEmpty);
        final flattenedBefores = run.containers.expand(
          (container) => container['befores'] as List<dynamic>,
        );
        expect(
          flattenedBefores.any((fixture) => fixture['name'] == 'setUp'),
          isTrue,
          reason: 'group-level skip is not forwarded to flutter_test, so '
              'fixtures registered inside the skipped group still run '
              'before the nested test self-skips',
        );
      });
    });

    test('records a retry parameter across testWidgets retries', () async {
      final run =
          await _runFlutterSample('retry_always_fails_widget_sample.dart');

      await step(
          'Verify both retry attempts write a result and one carries retry=1',
          (_) async {
        expect(run.exitCode, isNot(0), reason: run.output);
        expect(run.resultFiles, hasLength(2),
            reason: 'initial attempt plus one retry');

        final retryParameters = run.results
            .expand(
                (result) => result['parameters'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .where((parameter) => parameter['name'] == 'retry')
            .toList();
        expect(retryParameters, hasLength(1));
        expect(retryParameters.single['value'], '1');
      });
    });

    test(
        'keeps per-file labels, steps, and attachments isolated when running multiple sample files together',
        () async {
      final run = await _runFlutterSamples(const <String>[
        'concurrency_alpha_widget_sample.dart',
        'concurrency_beta_widget_sample.dart',
      ]);

      await step(
          'Verify sample files run together do not leak labels, steps, or attachments',
          (_) async {
        expect(run.exitCode, 0, reason: run.output);
        expect(run.resultFiles, hasLength(2));

        final alpha = run.results.singleWhere(
          (result) =>
              result['name'] == 'concurrency isolation widget sample alpha',
        );
        final beta = run.results.singleWhere(
          (result) =>
              result['name'] == 'concurrency isolation widget sample beta',
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
      });
    });

    test(
        'attaches a screenshot on failure when auto screenshot-on-failure is enabled',
        () async {
      final run = await _runFlutterSample(
        'failing_with_screenshot_sample.dart',
        sampleDirSegments: const <String>['test', 'e2e', 'screenshot_samples'],
      );

      await step('Verify a PNG screenshot is attached to the failed result',
          (_) async {
        expect(run.exitCode, isNot(0), reason: run.output);
        expect(run.resultFiles, hasLength(1));

        final result = run.results.single;
        expect(result['name'], 'fails after pumping a widget');
        expect(result['status'], 'failed');

        final attachment =
            _findAttachment(result, name: 'screenshot-on-failure');
        expect(attachment, isNotNull, reason: run.output);
        expect(attachment!['type'], 'image/png');

        final bytes = File(
          p.join(run.resultsDir.path, attachment['source'] as String),
        ).readAsBytesSync();
        _expectPngMagicBytes(bytes);
      });
    });

    test(
        'attaches golden-actual and failure diff PNGs on a golden mismatch when auto golden-diff attach is enabled',
        () async {
      final run = await _runFlutterSample(
        'golden_mismatch_sample.dart',
        sampleDirSegments: const <String>['test', 'e2e', 'golden_samples'],
      );

      await step(
          'Verify golden-actual and disk failure diffs are attached to the failed result',
          (_) async {
        expect(run.exitCode, isNot(0), reason: run.output);
        expect(run.resultFiles, hasLength(1));

        final result = run.results.single;
        expect(result['name'], 'mismatches the committed golden file');
        expect(result['status'], isNot('passed'));

        final actualAttachment = _findAttachment(result, name: 'golden-actual');
        expect(actualAttachment, isNotNull, reason: run.output);
        expect(actualAttachment!['type'], 'image/png');
        _expectPngMagicBytes(
          File(
            p.join(run.resultsDir.path, actualAttachment['source'] as String),
          ).readAsBytesSync(),
        );

        // `LocalFileComparator` always writes `masterImage`/`testImage`
        // diffs on a mismatch (`maskedDiff`/`isolatedDiff` are only added
        // for same-size pixel mismatches), so these two are asserted
        // unconditionally while the other two remain best-effort.
        for (final suffix in const ['masterImage', 'testImage']) {
          final diffAttachment =
              _findAttachment(result, name: 'golden-$suffix');
          expect(diffAttachment, isNotNull, reason: run.output);
          _expectPngMagicBytes(
            File(
              p.join(run.resultsDir.path, diffAttachment!['source'] as String),
            ).readAsBytesSync(),
          );
        }
      });
    });
  });
}

/// Finds an attachment named [name] anywhere among a result's top-level
/// attachments or its (possibly attachment-wrapper) steps.
Map<String, dynamic>? _findAttachment(
  Map<String, dynamic> result, {
  required String name,
}) {
  final topLevel = (result['attachments'] as List<dynamic>? ?? const [])
      .cast<Map<String, dynamic>>();
  for (final attachment in topLevel) {
    if (attachment['name'] == name) {
      return attachment;
    }
  }
  final steps = (result['steps'] as List<dynamic>? ?? const [])
      .cast<Map<String, dynamic>>();
  for (final step in steps) {
    final stepAttachments = (step['attachments'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    for (final attachment in stepAttachments) {
      if (attachment['name'] == name) {
        return attachment;
      }
    }
    final nested = _findAttachment(step, name: name);
    if (nested != null) {
      return nested;
    }
  }
  return null;
}

void _expectPngMagicBytes(List<int> bytes) {
  const pngMagicBytes = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  expect(bytes.length, greaterThanOrEqualTo(pngMagicBytes.length));
  expect(bytes.sublist(0, pngMagicBytes.length), pngMagicBytes);
}

void _expectOwnLabelOnly(
  Map<String, dynamic> result, {
  required String own,
  required String other,
}) {
  final labels =
      (result['labels'] as List<dynamic>).cast<Map<String, dynamic>>();
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
  final attachmentSteps =
      (step['steps'] as List<dynamic>).cast<Map<String, dynamic>>();
  expect(attachmentSteps, hasLength(1));
  final attachments = (attachmentSteps.single['attachments'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  expect(attachments, hasLength(1));
  return attachments.single;
}

class _FlutterSampleRun {
  _FlutterSampleRun({
    required this.exitCode,
    required this.output,
    required this.resultsDir,
    required this.resultFiles,
    required this.results,
    required this.containerFiles,
    required this.containers,
    required Directory tempDir,
  }) : _tempDir = tempDir;

  final int exitCode;
  final String output;
  final Directory resultsDir;
  final List<File> resultFiles;
  final List<Map<String, dynamic>> results;
  final List<File> containerFiles;
  final List<Map<String, dynamic>> containers;
  final Directory _tempDir;

  Future<void> dispose() async {
    if (_tempDir.existsSync()) {
      await _tempDir.delete(recursive: true);
    }
  }
}

Future<_FlutterSampleRun> _runFlutterSample(
  String sampleName, {
  String? testPlanSelector,
  List<String> sampleDirSegments = const <String>['test', 'samples'],
}) {
  return _runFlutterSamples(
    <String>[sampleName],
    testPlanSelector: testPlanSelector,
    sampleDirSegments: sampleDirSegments,
  );
}

/// Runs one or more fixtures in a single `flutter test` invocation, so
/// multiple suite files execute together (each still isolated by the
/// Flutter test runner's own per-suite process/VM model). Every call uses
/// its own unique `ALLURE_RESULTS_DIR` so this subprocess's results never
/// collide with the outer harness's own results directory.
///
/// [sampleDirSegments] defaults to `test/samples/`, but callers running
/// fixtures under a directory-scoped `flutter_test_config.dart` (for
/// example `test/e2e/screenshot_samples/`) pass that directory's path
/// segments instead.
Future<_FlutterSampleRun> _runFlutterSamples(
  List<String> sampleNames, {
  String? testPlanSelector,
  List<String> sampleDirSegments = const <String>['test', 'samples'],
}) async {
  final packageRoot = Directory.current;
  final tempDir = await Directory.systemTemp.createTemp('allure_flutter_e2e_');
  final resultsDir = Directory(p.join(tempDir.path, 'allure-results'));

  final environment = <String, String>{
    'ALLURE_RESULTS_DIR': resultsDir.path,
  };

  if (testPlanSelector != null) {
    final testPlanFile = File(p.join(tempDir.path, 'testplan.json'));
    await testPlanFile.writeAsString(
      jsonEncode(<String, dynamic>{
        'version': '1.0',
        'tests': <Map<String, String>>[
          {'selector': testPlanSelector},
        ],
      }),
    );
    environment['ALLURE_TESTPLAN_PATH'] = testPlanFile.path;
  }

  final process = await Process.run(
    'flutter',
    <String>[
      'test',
      for (final sampleName in sampleNames)
        p.joinAll(<String>[...sampleDirSegments, sampleName]),
    ],
    workingDirectory: packageRoot.path,
    environment: environment,
  );

  final producedFiles = resultsDir.existsSync()
      ? resultsDir.listSync().whereType<File>().toList()
      : <File>[];

  final resultFiles = producedFiles
      .where((file) => file.path.endsWith('-result.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final containerFiles = producedFiles
      .where((file) => file.path.endsWith('-container.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final results = resultFiles
      .map(
          (file) => jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)
      .toList();
  final containers = containerFiles
      .map(
          (file) => jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)
      .toList();

  final run = _FlutterSampleRun(
    exitCode: process.exitCode,
    output: '${process.stdout}\n${process.stderr}',
    resultsDir: resultsDir,
    resultFiles: resultFiles,
    results: results,
    containerFiles: containerFiles,
    containers: containers,
    tempDir: tempDir,
  );
  addTearDown(run.dispose);
  return run;
}
