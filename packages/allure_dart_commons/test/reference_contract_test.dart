import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:allure_dart_commons/allure_dart_commons.dart';
import 'package:allure_dart_test/adapter_support.dart' as adapter_support;
import 'package:allure_dart_test/allure_dart_test.dart'
    show attachment, description, installAllure, step;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  installAllure();

  group('reference parity helpers', () {
    test('derives testCaseId and historyId from sorted non-excluded parameters',
        () async {
      await description('''
Verifies that the commons lifecycle derives stable Allure `testCaseId` and `historyId` values from a test's full name and parameters.

The result should use the MD5 hash of the full name as `testCaseId`, include only non-excluded parameters in the `historyId` suffix, and ignore excluded parameters such as retry metadata.
''');
      final resultsDir = await step(
        'Create isolated Allure results directory',
        (_) => Directory.systemTemp.createTemp('allure_dart_reference_'),
      );
      addTearDown(() async {
        if (resultsDir.existsSync()) {
          await resultsDir.delete(recursive: true);
        }
      });

      const fullName = 'suite/file#parameterized';
      late Map<String, dynamic> result;

      await step(
        'Write result with included and excluded parameters',
        (_) async {
          final lifecycle = AllureLifecycle(
            writer: AllureResultsWriter(outputDirectory: resultsDir.path),
          );
          final testUuid = lifecycle.startTest(
            name: 'parameterized',
            fullName: fullName,
            parameters: <AllureParameter>[
              const AllureParameter(name: 'browser', value: 'webkit'),
              const AllureParameter(
                name: 'retry',
                value: '1',
                excluded: true,
              ),
              const AllureParameter(name: 'attempt', value: '2'),
            ],
          );

          await lifecycle.stopTest(
            testUuid,
            status: AllureStatus.passed,
          );
          await lifecycle.writeTest(testUuid);

          final resultFile = resultsDir
              .listSync()
              .whereType<File>()
              .singleWhere((file) => file.path.endsWith('-result.json'));
          final resultJson = resultFile.readAsStringSync();
          result = jsonDecode(resultJson) as Map<String, dynamic>;

          await _attachDirectoryFiles(resultsDir);
        },
      );

      await step(
        'Compare generated identifiers with expected hashes',
        (_) async {
          final expectedTestCaseId = md5Hash(fullName);
          final expectedHistoryId =
              '$expectedTestCaseId:${md5Hash('attempt:2,browser:webkit')}';
          await _verifyValue(
            'Verify testCaseId equals MD5 of the full name',
            expected: expectedTestCaseId,
            actual: result['testCaseId'],
          );
          await step(
            'Verify historyId includes sorted non-excluded parameters',
            (check) async {
              await check.parameter('fullName', fullName);
              await check.parameter('includedParameters', <String, String>{
                'attempt': '2',
                'browser': 'webkit',
              });
              await check.parameter('excludedParameters', <String, String>{
                'retry': '1',
              });
              await check.parameter('expected', expectedHistoryId);
              await check.parameter('actual', result['historyId']);
              expect(result['historyId'], expectedHistoryId);
            },
          );
        },
      );
    });

    test('keeps skipped tests in pending stage', () async {
      await description('''
Verifies how the commons lifecycle serializes skipped tests when no explicit stage is provided.

The written Allure result should keep the test status as `skipped` and resolve the stage to `pending`, matching the report contract for tests that were scheduled but not executed.
''');
      final resultsDir = await step(
        'Create isolated Allure results directory',
        (_) => Directory.systemTemp.createTemp('allure_dart_reference_'),
      );
      addTearDown(() async {
        if (resultsDir.existsSync()) {
          await resultsDir.delete(recursive: true);
        }
      });

      late Map<String, dynamic> result;

      await step(
        'Write skipped result without an explicit stage',
        (_) async {
          final lifecycle = AllureLifecycle(
            writer: AllureResultsWriter(outputDirectory: resultsDir.path),
          );
          final testUuid = lifecycle.startTest(
            name: 'skipped',
            fullName: 'suite/file#skipped',
          );

          await lifecycle.stopTest(
            testUuid,
            status: AllureStatus.skipped,
          );
          await lifecycle.writeTest(testUuid);

          final resultFile = resultsDir
              .listSync()
              .whereType<File>()
              .singleWhere((file) => file.path.endsWith('-result.json'));
          final resultJson = resultFile.readAsStringSync();
          result = jsonDecode(resultJson) as Map<String, dynamic>;

          await _attachDirectoryFiles(resultsDir);
        },
      );

      await step(
        'Verify skipped status resolves to pending stage',
        (_) async {
          await _verifyValue(
            'Verify skipped result status',
            expected: 'skipped',
            actual: result['status'],
          );
          await _verifyValue(
            'Verify skipped result stage',
            expected: 'pending',
            actual: result['stage'],
          );
        },
      );
    });

    test('writes globals, categories, and environment artifacts', () async {
      await description('''
Verifies that repository-level Allure artifacts are written alongside normal result data when the lifecycle is configured with environment information and category definitions.

The writer should create `environment.properties`, `categories.json`, and a globals file for the reported error, and the category definition should preserve the configured message-matching expression.
''');
      final resultsDir = await step(
        'Create isolated Allure results directory',
        (_) => Directory.systemTemp.createTemp('allure_dart_reference_'),
      );
      addTearDown(() async {
        if (resultsDir.existsSync()) {
          await resultsDir.delete(recursive: true);
        }
      });

      await step(
        'Write global error with environment and category configuration',
        (_) async {
          final lifecycle = AllureLifecycle(
            writer: AllureResultsWriter(outputDirectory: resultsDir.path),
            environmentInfo: const <String, String?>{
              'os': 'macos',
              'empty': null,
            },
            categories: <AllureCategory>[
              AllureCategory(
                name: 'Infrastructure',
                messageRegex: RegExp('boom'),
              ),
            ],
          );

          await lifecycle.writeGlobalError(
            const AllureStatusDetails(message: 'boom'),
          );

          await _attachDirectoryFiles(resultsDir);
        },
      );

      await step(
        'Verify global artifacts and category expression',
        (_) async {
          final environmentFile =
              File(p.join(resultsDir.path, 'environment.properties'));
          final categoriesFile =
              File(p.join(resultsDir.path, 'categories.json'));
          final globalsFiles = resultsDir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('-globals.json'))
              .toList();
          final environmentExists = environmentFile.existsSync();
          final categoriesExists = categoriesFile.existsSync();
          final environmentProperties =
              environmentExists ? environmentFile.readAsStringSync() : null;
          final categories = categoriesExists
              ? jsonDecode(categoriesFile.readAsStringSync()) as List<dynamic>
              : const <dynamic>[];
          final globalsFileNames = globalsFiles
              .map((file) => p.basename(file.path))
              .toList()
            ..sort();

          await step(
            'Verify environment.properties exists',
            (check) async {
              await check.parameter('expected', true);
              await check.parameter('actual', environmentExists);
              expect(environmentExists, isTrue);
            },
          );
          await step(
            'Verify environment.properties content',
            (check) async {
              await check.parameter('expected', 'os=macos\n');
              await check.parameter('actual', environmentProperties);
              expect(environmentProperties, 'os=macos\n');
            },
          );
          await step(
            'Verify categories.json exists',
            (check) async {
              await check.parameter('expected', true);
              await check.parameter('actual', categoriesExists);
              expect(categoriesExists, isTrue);
            },
          );
          await step(
            'Verify categories.json has one category',
            (check) async {
              await check.parameter('expected', 1);
              await check.parameter('actual', categories.length);
              expect(categories, hasLength(1));
            },
          );
          await step(
            'Verify category messageRegex equals boom',
            (check) async {
              final actualMessageRegex = categories.isEmpty
                  ? null
                  : (categories.single as Map<String, dynamic>)['messageRegex'];
              await check.parameter('expected', 'boom');
              await check.parameter('actual', actualMessageRegex);
              expect(actualMessageRegex, 'boom');
            },
          );
          await step(
            'Verify globals error artifact was written',
            (check) async {
              await check.parameter(
                'expected',
                'at least one *-globals.json file',
              );
              await check.parameter('actual', globalsFileNames);
              expect(globalsFiles, isNotEmpty);
            },
          );
        },
      );
    });

    test('serializes extended model fields and executor sidecar', () async {
      await description('''
Verifies the extended Allure model fields required by the reference contract.

The lifecycle should preserve `testCaseName`, status classification flags, optional container metadata, and the `executor.json` sidecar while still writing normal result and container files.
''');
      final resultsDir = await step(
        'Create isolated Allure results directory',
        (_) => Directory.systemTemp.createTemp('allure_dart_reference_'),
      );
      addTearDown(() async {
        if (resultsDir.existsSync()) {
          await resultsDir.delete(recursive: true);
        }
      });

      late Map<String, dynamic> result;
      late Map<String, dynamic> container;
      late Map<String, dynamic> executor;

      await step(
        'Write result, scope container, and executor metadata',
        (_) async {
          final lifecycle = AllureLifecycle(
            writer: AllureResultsWriter(outputDirectory: resultsDir.path),
            executorInfo: const AllureExecutorInfo(
              name: 'GitHub Actions',
              type: 'github',
              buildName: 'reference-contract',
              buildOrder: 42,
            ),
          );
          final scopeId = lifecycle.ensureScope(
            id: 'scope:extended',
            name: 'extended scope',
            expectedChildrenCount: 1,
          );
          final fixtureUuid = lifecycle.startFixture(
            scopeId: scopeId,
            before: true,
            name: 'setUpAll',
          );
          await lifecycle.handleRuntimeMessage(
            RuntimeMessage(
              type: 'metadata',
              data: <String, Object?>{
                'description': 'scope defaults',
                'links': <Map<String, String>>[
                  const AllureLink(
                    url: 'https://example.test/scope',
                    name: 'scope',
                    type: 'custom',
                  ).toJson(),
                ],
              },
            ),
            rootUuid: fixtureUuid,
          );
          await lifecycle.stopFixture(
            fixtureUuid,
            status: AllureStatus.passed,
          );

          final testUuid = lifecycle.startTest(
            name: 'display name',
            fullName: 'suite/file#logical name',
            testCaseName: 'logical name',
            statusDetails: const AllureStatusDetails(
              known: true,
              muted: false,
              flaky: true,
            ),
            scopeIds: <String>[scopeId],
          );
          await lifecycle.stopTest(testUuid, status: AllureStatus.passed);
          await lifecycle.writeTest(testUuid);

          final resultFile = resultsDir
              .listSync()
              .whereType<File>()
              .singleWhere((file) => file.path.endsWith('-result.json'));
          final containerFile = resultsDir
              .listSync()
              .whereType<File>()
              .singleWhere((file) => file.path.endsWith('-container.json'));
          final executorFile = File(p.join(resultsDir.path, 'executor.json'));
          result =
              jsonDecode(resultFile.readAsStringSync()) as Map<String, dynamic>;
          container = jsonDecode(containerFile.readAsStringSync())
              as Map<String, dynamic>;
          executor = jsonDecode(executorFile.readAsStringSync())
              as Map<String, dynamic>;

          await _attachDirectoryFiles(resultsDir);
        },
      );

      await step('Verify extended serialized fields', (_) async {
        final statusDetails = result['statusDetails'] as Map<String, dynamic>;
        await _verifyValue(
          'Verify result testCaseName',
          expected: 'logical name',
          actual: result['testCaseName'],
        );
        await _verifyValue(
          'Verify statusDetails.known flag',
          expected: true,
          actual: statusDetails['known'],
        );
        await _verifyValue(
          'Verify statusDetails.muted flag',
          expected: false,
          actual: statusDetails['muted'],
        );
        await _verifyValue(
          'Verify statusDetails.flaky flag',
          expected: true,
          actual: statusDetails['flaky'],
        );
        await _verifyValue(
          'Verify container description',
          expected: 'scope defaults',
          actual: container['description'],
        );
        await _verifyValue(
          'Verify container link count',
          expected: 1,
          actual: (container['links'] as List<dynamic>).length,
        );
        await _verifyValue(
          'Verify container start is a timestamp',
          expected: 'integer timestamp',
          actual: container['start'],
          matcher: isA<int>(),
        );
        await _verifyValue(
          'Verify container stop is a timestamp',
          expected: 'integer timestamp',
          actual: container['stop'],
          matcher: isA<int>(),
        );
        await _verifyValue(
          'Verify executor name',
          expected: 'GitHub Actions',
          actual: executor['name'],
        );
        await _verifyValue(
          'Verify executor buildOrder',
          expected: 42,
          actual: executor['buildOrder'],
        );
      });
    });

    test('notifies lifecycle listeners without aborting operations', () async {
      await description('''
Verifies that lifecycle listeners can observe and mutate mutable lifecycle state, and that listener failures are isolated from reporting operations.

The listener should see start, stop, write, step, container, attachment, global attachment, and global error events. A deliberately throwing listener must be reported to stderr but must not prevent result files from being written.
''');
      final resultsDir = await step(
        'Create isolated Allure results directory',
        (_) => Directory.systemTemp.createTemp('allure_dart_reference_'),
      );
      addTearDown(() async {
        if (resultsDir.existsSync()) {
          await resultsDir.delete(recursive: true);
        }
      });

      final events = <String>[];
      await step('Exercise lifecycle listener callbacks', (_) async {
        final lifecycle = AllureLifecycle(
          writer: AllureResultsWriter(outputDirectory: resultsDir.path),
          listeners: <AllureLifecycleListener>[
            _RecordingLifecycleListener(events),
            _ThrowingLifecycleListener(),
          ],
        );
        final scopeId = lifecycle.ensureScope(
          id: 'scope:listeners',
          expectedChildrenCount: 1,
        );
        final fixtureUuid = lifecycle.startFixture(
          scopeId: scopeId,
          before: true,
          name: 'setUp',
        );
        await lifecycle.stopFixture(fixtureUuid, status: AllureStatus.passed);

        final testUuid = lifecycle.startTest(
          name: 'listener test',
          fullName: 'suite/listener#test',
          scopeIds: <String>[scopeId],
        );
        lifecycle.startStep(testUuid, 'listener step');
        lifecycle.stopStep(testUuid, status: AllureStatus.passed);
        await lifecycle.addAttachmentToRoot(
          testUuid,
          name: 'listener attachment',
          content: utf8.encode('payload'),
          contentType: 'text/plain',
          fileExtension: 'txt',
        );
        await lifecycle.stopTest(testUuid, status: AllureStatus.passed);
        await lifecycle.writeTest(testUuid);
        await lifecycle.writeGlobalAttachment(
          name: 'global log',
          content: utf8.encode('global payload'),
          type: 'text/plain',
          fileExtension: 'txt',
        );
        await lifecycle.writeGlobalError(
          const AllureStatusDetails(message: 'global failure'),
        );

        await _attachDirectoryFiles(resultsDir);
      });

      await step('Verify listener callbacks and mutation', (_) async {
        for (final event in const <String>[
          'beforeTestStart',
          'afterTestStop',
          'beforeTestWrite',
          'afterTestWrite',
          'afterStepStop:listener step',
          'beforeContainerWrite',
          'afterContainerWrite',
          'attachment:listener attachment',
          'globalAttachment:global log',
          'globalError:global failure',
        ]) {
          await _verifyContains(
            'Verify listener emitted $event',
            expectedValue: event,
            actualValues: events,
          );
        }
        final resultFile = resultsDir
            .listSync()
            .whereType<File>()
            .singleWhere((file) => file.path.endsWith('-result.json'));
        final result =
            jsonDecode(resultFile.readAsStringSync()) as Map<String, dynamic>;
        await _verifyContains(
          'Verify listener mutation label is written',
          expectedValue: {'name': 'listener', 'value': 'mutated'},
          actualValues: result['labels'] as List<dynamic>,
        );
      });
    });

    test('writes prepared and stream attachments durably', () async {
      await description('''
Verifies the prepared and streaming attachment APIs used for late or larger artifacts.

The result should not reference an attachment until the producer has fully written the payload, and the stored payloads should preserve the original stream and prepared-file content.
''');
      final resultsDir = await step(
        'Create isolated Allure results directory',
        (_) => Directory.systemTemp.createTemp('allure_dart_reference_'),
      );
      addTearDown(() async {
        if (resultsDir.existsSync()) {
          await resultsDir.delete(recursive: true);
        }
      });

      late Map<String, dynamic> result;
      await step('Write prepared and stream attachments', (_) async {
        final lifecycle = AllureLifecycle(
          writer: AllureResultsWriter(outputDirectory: resultsDir.path),
        );
        final testUuid = lifecycle.startTest(
          name: 'durable attachments',
          fullName: 'suite/attachments#durable',
        );
        await lifecycle.addPreparedAttachmentToRoot(
          testUuid,
          name: 'prepared payload',
          contentType: 'text/plain',
          fileExtension: 'txt',
          write: (prepared) async {
            await File(prepared.path).writeAsString('prepared-content');
          },
        );
        await lifecycle.addAttachmentStreamToRoot(
          testUuid,
          name: 'stream payload',
          contentType: 'text/plain',
          fileExtension: 'txt',
          content: Stream<List<int>>.fromIterable(<List<int>>[
            utf8.encode('stream-'),
            utf8.encode('content'),
          ]),
        );
        await lifecycle.stopTest(testUuid, status: AllureStatus.passed);
        await lifecycle.writeTest(testUuid);

        final resultFile = resultsDir
            .listSync()
            .whereType<File>()
            .singleWhere((file) => file.path.endsWith('-result.json'));
        result =
            jsonDecode(resultFile.readAsStringSync()) as Map<String, dynamic>;
        await _attachDirectoryFiles(resultsDir);
      });

      await step('Verify attachment payload files', (_) async {
        final attachments = result['attachments'] as List<dynamic>;
        await _verifyValue(
          'Verify result references two attachments',
          expected: 2,
          actual: attachments.length,
        );
        final contents = <String, String>{};
        for (final attachment in attachments.cast<Map<String, dynamic>>()) {
          contents[attachment['name'] as String] = File(
            p.join(resultsDir.path, attachment['source'] as String),
          ).readAsStringSync();
        }
        await _verifyValue(
          'Verify prepared attachment payload content',
          expected: 'prepared-content',
          actual: contents['prepared payload'],
        );
        await _verifyValue(
          'Verify stream attachment payload content',
          expected: 'stream-content',
          actual: contents['stream payload'],
        );
      });
    });

    test('degrades invalid test plans to unavailable plans', () async {
      await description('''
Verifies that malformed, unsupported, and missing Allure test plans do not fail the process.

The parser should warn and return `null` so callers can continue without filtering when the plan cannot be trusted.
''');
      final tempDir = await step(
        'Create invalid test plan files',
        (_) async {
          final directory =
              await Directory.systemTemp.createTemp('allure_dart_testplan_');
          addTearDown(() async {
            if (directory.existsSync()) {
              await directory.delete(recursive: true);
            }
          });
          await File(p.join(directory.path, 'invalid.json')).writeAsString('{');
          await File(p.join(directory.path, 'unsupported.json')).writeAsString(
            jsonEncode(<String, Object?>{
              'version': '2.0',
              'tests': <Object?>[],
            }),
          );
          await File(p.join(directory.path, 'malformed-entry.json'))
              .writeAsString(
            jsonEncode(<String, Object?>{
              'version': '1.0',
              'tests': <Object?>[
                <String, Object?>{'name': 'missing id and selector'},
              ],
            }),
          );
          await _attachDirectoryFiles(directory);
          return directory;
        },
      );

      await step('Verify invalid test plans are ignored', (_) {
        expect(
          adapter_support.parseTestPlan(
            <String, String>{
              'ALLURE_TESTPLAN_PATH': p.join(tempDir.path, 'missing.json'),
            },
          ),
          isNull,
        );
        expect(
          adapter_support.parseTestPlan(
            <String, String>{
              'ALLURE_TESTPLAN_PATH': p.join(tempDir.path, 'invalid.json'),
            },
          ),
          isNull,
        );
        expect(
          adapter_support.parseTestPlan(
            <String, String>{
              'ALLURE_TESTPLAN_PATH': p.join(
                tempDir.path,
                'unsupported.json',
              ),
            },
          ),
          isNull,
        );
        expect(
          adapter_support.parseTestPlan(
            <String, String>{
              'ALLURE_TESTPLAN_PATH': p.join(
                tempDir.path,
                'malformed-entry.json',
              ),
            },
          ),
          isNull,
        );
      });
    });

    test('isolates concurrent zone contexts for steps and attachments',
        () async {
      await description('''
Verifies that concurrent asynchronous work keeps Allure steps and attachments attached to the execution root active when each task was created.

Two tests are run through separate zones at the same time. Each result should contain only the step and attachment produced inside that zone.
''');
      final resultsDir = await step(
        'Create isolated Allure results directory',
        (_) => Directory.systemTemp.createTemp('allure_dart_reference_'),
      );
      addTearDown(() async {
        if (resultsDir.existsSync()) {
          await resultsDir.delete(recursive: true);
        }
      });

      late List<Map<String, dynamic>> results;
      await step('Run concurrent lifecycle roots', (_) async {
        final lifecycle = AllureLifecycle(
          writer: AllureResultsWriter(outputDirectory: resultsDir.path),
        );
        final runtime = MessageTestRuntime(
          sink: lifecycle,
          contextResolver: getZoneExecutionContext,
        );
        final first = lifecycle.startTest(
          name: 'first',
          fullName: 'suite/concurrency#first',
        );
        final second = lifecycle.startTest(
          name: 'second',
          fullName: 'suite/concurrency#second',
        );

        Future<void> runRoot(String uuid, String name) {
          return runWithAllureContext(
            rootUuid: uuid,
            testUuid: uuid,
            body: () async {
              await runtime.send(
                RuntimeMessage(
                  type: 'step_start',
                  data: <String, Object?>{'name': '$name step'},
                ),
              );
              await Future<void>.delayed(Duration.zero);
              await runtime.send(
                RuntimeMessage(
                  type: 'attachment_content',
                  data: <String, Object?>{
                    'name': '$name attachment',
                    'content': '$name payload',
                    'encoding': 'utf8',
                    'contentType': 'text/plain',
                  },
                ),
              );
              await runtime.send(
                RuntimeMessage(
                  type: 'step_stop',
                  data: <String, Object?>{'status': 'passed'},
                ),
              );
            },
          );
        }

        await Future.wait(<Future<void>>[
          runRoot(first, 'first'),
          runRoot(second, 'second'),
        ]);
        await lifecycle.stopTest(first, status: AllureStatus.passed);
        await lifecycle.stopTest(second, status: AllureStatus.passed);
        await lifecycle.writeTest(first);
        await lifecycle.writeTest(second);

        results = resultsDir
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('-result.json'))
            .map((file) =>
                jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)
            .toList()
          ..sort(
              (a, b) => (a['name'] as String).compareTo(b['name'] as String));
        await _attachDirectoryFiles(resultsDir);
      });

      await step('Verify roots kept separate evidence', (_) async {
        await _verifyValue(
          'Verify two concurrent roots were written',
          expected: 2,
          actual: results.length,
        );
        for (final result in results) {
          final name = result['name'] as String;
          final steps = result['steps'] as List<dynamic>;
          await _verifyValue(
            'Verify $name root has one step',
            expected: 1,
            actual: steps.length,
          );
          final step = steps.single as Map<String, dynamic>;
          await _verifyValue(
            'Verify $name root step name',
            expected: '$name step',
            actual: step['name'],
          );
          final attachments = step['attachments'] as List<dynamic>;
          await _verifyValue(
            'Verify $name root has one step attachment',
            expected: 1,
            actual: attachments.length,
          );
          await _verifyValue(
            'Verify $name root attachment name',
            expected: '$name attachment',
            actual: (attachments.single as Map<String, dynamic>)['name'],
          );
        }
      });
    });
  });
}

Future<void> _attachDirectoryFiles(Directory directory) async {
  for (final file in directory.listSync().whereType<File>().toList()
    ..sort((left, right) => left.path.compareTo(right.path))) {
    await attachment(
      p.relative(file.path, from: directory.path),
      file.readAsBytesSync(),
      contentType: _contentTypeForArtifact(file),
      fileExtension: _extensionForArtifact(file),
    );
  }
}

Future<void> _verifyValue(
  String name, {
  required Object? expected,
  required Object? actual,
  Matcher? matcher,
}) {
  return step(name, (check) async {
    await check.parameter('expected', expected);
    await check.parameter('actual', actual);
    expect(actual, matcher ?? expected);
  });
}

Future<void> _verifyContains(
  String name, {
  required Object? expectedValue,
  required List<dynamic> actualValues,
}) {
  return step(name, (check) async {
    await check.parameter('expected', expectedValue);
    await check.parameter('actual', actualValues);
    final expectedMatcher = equals(expectedValue);
    final found = actualValues.any(
      (actualValue) =>
          expectedMatcher.matches(actualValue, <Object?, Object?>{}),
    );
    expect(found, isTrue);
  });
}

String _contentTypeForArtifact(File file) {
  return p.extension(file.path) == '.json' ? 'application/json' : 'text/plain';
}

String _extensionForArtifact(File file) {
  final extension = p.extension(file.path);
  return extension.isEmpty ? 'txt' : extension.substring(1);
}

class _RecordingLifecycleListener extends AllureLifecycleListener {
  const _RecordingLifecycleListener(this.events);

  final List<String> events;

  @override
  void beforeTestStart(AllureTestResult result) {
    events.add('beforeTestStart');
  }

  @override
  void afterTestStop(AllureTestResult result) {
    events.add('afterTestStop');
  }

  @override
  void beforeTestWrite(AllureTestResult result) {
    events.add('beforeTestWrite');
    result.labels.add(const AllureLabel(name: 'listener', value: 'mutated'));
  }

  @override
  void afterTestWrite(AllureTestResult result) {
    events.add('afterTestWrite');
  }

  @override
  void afterStepStop(AllureStepResult result) {
    events.add('afterStepStop:${result.name}');
  }

  @override
  void beforeContainerWrite(AllureTestResultContainer container) {
    events.add('beforeContainerWrite');
  }

  @override
  void afterContainerWrite(AllureTestResultContainer container) {
    events.add('afterContainerWrite');
  }

  @override
  void onAttachment(String rootUuid, AllureAttachment attachment) {
    events.add('attachment:${attachment.name}');
  }

  @override
  void onGlobalAttachment(AllureGlobalAttachment attachment) {
    events.add('globalAttachment:${attachment.name}');
  }

  @override
  void onGlobalError(AllureGlobalError error) {
    events.add('globalError:${error.message}');
  }
}

class _ThrowingLifecycleListener extends AllureLifecycleListener {
  @override
  void beforeTestStart(AllureTestResult result) {
    throw StateError('listener boom');
  }
}
