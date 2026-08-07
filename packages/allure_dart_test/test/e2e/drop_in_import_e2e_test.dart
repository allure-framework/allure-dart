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
        expect(
          run.exitCode,
          isNonZero,
          reason: 'sample must fail\n${run.output}',
        );
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

      await harnessStep(
        'Verify drop-in group title path and hook containers',
        () {
          expect(run.exitCode, 0, reason: run.output);
          expect(run.resultFiles, hasLength(1));

          final result = run.results.single;
          _expectRuntimeBaseResultFields(
            result,
            expectedName: 'nested test uses hooks',
            expectedTitlePath: const [
              'test',
              'sample_test.dart',
              'parent group',
            ],
          );
          expect(result['status'], 'passed');
          expect(run.containerFiles, isNotEmpty);
          final flattenedFixtures = run.containers
              .map(
                (container) => <dynamic>[
                  ...(container['befores'] as List<dynamic>),
                  ...(container['afters'] as List<dynamic>),
                ],
              )
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
            flattenedFixtures.any(
              (fixture) => fixture['name'] == 'tearDownAll',
            ),
            isTrue,
          );
          for (final container in run.containers) {
            final children = (container['children'] as List<dynamic>)
                .cast<String>()
                .toList();
            expect(children.toSet().length, children.length);
          }
        },
      );
    });

    test('preserves representative package:test APIs unchanged', () async {
      final run = await _runDropInSample(sampleName: 'api_parity_sample.dart');

      await harnessStep(
        'Verify representative package:test APIs still behave natively',
        () {
          expect(
            run.exitCode,
            isNonZero,
            reason: 'sample must fail\n${run.output}',
          );
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
        },
      );
    });

    test(
      'does not duplicate hooks when combined with installAllure()',
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
          },
        );
      },
    );

    test(
      'propagates before fixture metadata and keeps after metadata local',
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
                containsPair('description', 'after fixture description'),
              ),
            );
            expect(
              afterFixtures.expand(
                (fixture) => fixture['parameters'] as List<dynamic>,
              ),
              contains(
                predicate<Map<dynamic, dynamic>>(
                  (parameter) =>
                      parameter['name'] == 'teardown-param' &&
                      parameter['value'] == 'after',
                ),
              ),
            );
          },
        );
      },
    );

    test(
      'derives tag and suite hierarchy labels for nested groups through drop-in import',
      () async {
        final run = await _runDropInSample(
          sampleName: 'tags_and_suite_sample.dart',
        );

        await harnessStep(
          'Verify native tags become a tag label and nested groups become suite labels',
          () {
            expect(run.exitCode, 0, reason: run.output);
            expect(run.resultFiles, hasLength(1));

            final result = run.results.single;
            _expectRuntimeBaseResultFields(
              result,
              expectedName: 'tagged nested test',
              expectedTitlePath: const [
                'test',
                'sample_test.dart',
                'outer group',
                'inner group',
                'deepest group',
              ],
            );
            expect(result['status'], 'passed');
            expect(
              result['labels'],
              containsAll(<Map<String, String>>[
                {'name': 'tag', 'value': 'smoke'},
                {'name': 'parentSuite', 'value': 'outer group'},
                {'name': 'suite', 'value': 'inner group'},
                {'name': 'subSuite', 'value': 'deepest group'},
              ]),
            );
          },
        );
      },
    );

    test('passes testOn and onPlatform through the drop-in wrapper', () async {
      final run = await _runDropInSample(
        sampleName: 'platform_passthrough_sample.dart',
      );

      await harnessStep(
        'Verify testOn/onPlatform passthrough still writes a passed result',
        () {
          expect(run.exitCode, 0, reason: run.output);
          expect(run.resultFiles, hasLength(1));

          final result = run.results.single;
          _expectRuntimeBaseResultFields(
            result,
            expectedName: 'drop in platform passthrough sample',
          );
          expect(result['status'], 'passed');
        },
      );
    });

    test('writes a skipped result for a declaration-skipped test', () async {
      final run = await _runDropInSample(
        sampleName: 'declaration_skip_sample.dart',
      );

      await harnessStep(
        'Verify declaration `skip: true` still writes a pending, skipped result',
        () {
          expect(run.exitCode, 0, reason: run.output);
          expect(run.resultFiles, hasLength(1));

          final result = run.results.single;
          _expectRuntimeBaseResultFields(
            result,
            expectedName: 'drop in declaration skip sample',
            expectedStage: 'pending',
          );
          expect(result['status'], 'skipped');
        },
      );
    });

    test(
      'writes a skipped result for a test nested in a skipped group',
      () async {
        final run = await _runDropInSample(
          sampleName: 'group_skip_sample.dart',
        );

        await harnessStep(
          'Verify a group-level skip still schedules and skips nested tests',
          () {
            expect(run.exitCode, 0, reason: run.output);
            expect(run.resultFiles, hasLength(1));

            final result = run.results.single;
            _expectRuntimeBaseResultFields(
              result,
              expectedName: 'nested test in skipped group',
              expectedStage: 'pending',
              expectedTitlePath: const [
                'test',
                'sample_test.dart',
                'drop in skipped group',
              ],
            );
            expect(result['status'], 'skipped');
          },
        );
      },
    );

    test('skips test-plan excluded tests before the body runs', () async {
      final run = await _runDropInSample(
        sampleName: 'test_plan_sample.dart',
        testPlanContents:
            '{"version":"1.0","tests":[{"selector":"test/sample_test.dart#selected elsewhere"}]}',
      );

      await harnessStep(
        'Verify test-plan excluded drop-in test does not write a result',
        () {
          expect(run.exitCode, 0, reason: run.output);
          expect(run.resultFiles, isEmpty);
        },
      );
    });

    test('reports setUp fixture hook errors as global errors', () async {
      final run = await _runDropInSample(
        sampleName: 'fixture_error_setup_sample.dart',
      );

      await harnessStep(
        'Verify setUp failure writes a broken fixture and one matching global error',
        () {
          _expectFixtureHookGlobalError(
            run,
            hookName: 'setUp',
            boomText: 'setUp boom',
            expectBrokenFixture: true,
          );
        },
      );
    });

    test('reports tearDown fixture hook errors as global errors', () async {
      final run = await _runDropInSample(
        sampleName: 'fixture_error_teardown_sample.dart',
      );

      await harnessStep(
        'Verify tearDown failure writes a broken fixture and one matching global error',
        () {
          _expectFixtureHookGlobalError(
            run,
            hookName: 'tearDown',
            boomText: 'tearDown boom',
            expectBrokenFixture: true,
          );
        },
      );
    });

    test('reports setUpAll fixture hook errors as global errors', () async {
      final run = await _runDropInSample(
        sampleName: 'fixture_error_setup_all_sample.dart',
      );

      await harnessStep(
        'Verify setUpAll failure writes one matching global error without containers',
        () {
          // package:test skips the suite after setUpAll fails, so no test
          // children complete and Allure never flushes a fixture container.
          expect(
            run.containers,
            isEmpty,
            reason:
                'setUpAll failure leaves the package scope without completed '
                'children, so containers are not written\n${run.output}',
          );
          _expectFixtureHookGlobalError(
            run,
            hookName: 'setUpAll',
            boomText: 'setUpAll boom',
            expectBrokenFixture: false,
          );
        },
      );
    });

    test('reports tearDownAll fixture hook errors as global errors', () async {
      final run = await _runDropInSample(
        sampleName: 'fixture_error_teardown_all_sample.dart',
      );

      await harnessStep(
        'Verify tearDownAll failure writes a broken fixture and one matching global error',
        () {
          _expectFixtureHookGlobalError(
            run,
            hookName: 'tearDownAll',
            boomText: 'tearDownAll boom',
            expectBrokenFixture: true,
          );
        },
      );
    });

    test(
      'reports setUp and tearDown fixture hook errors together as global errors',
      () async {
        final run = await _runDropInSample(
          sampleName: 'fixture_error_setup_and_teardown_sample.dart',
        );

        await harnessStep(
          'Verify setUp failure still runs tearDown and both write globals and fixtures',
          () {
            expect(
              run.exitCode,
              isNonZero,
              reason: 'sample must fail\n${run.output}',
            );

            final fixtures = _allFixtures(run);
            for (final hookName in <String>['setUp', 'tearDown']) {
              final boomText = '$hookName boom';
              final hookFixtures = fixtures
                  .where((fixture) => fixture['name'] == hookName)
                  .toList();
              expect(
                hookFixtures,
                isNotEmpty,
                reason:
                    'expected $hookName fixture in containers\n${run.output}',
              );
              expect(
                hookFixtures.any(
                  (fixture) =>
                      (fixture['status'] == 'broken' ||
                          fixture['status'] == 'failed') &&
                      ((fixture['statusDetails']
                                      as Map<String, dynamic>?)?['message']
                                  as String? ??
                              '')
                          .contains(boomText),
                ),
                isTrue,
                reason:
                    'expected a broken/failed $hookName fixture containing '
                    '$boomText\n${run.output}',
              );
            }

            final allErrors = _allGlobalErrors(run);
            final messages = allErrors
                .map((error) => error['message'] as String? ?? '')
                .toList();
            expect(
              messages.where((message) => message.startsWith('setUp failed:')),
              hasLength(1),
              reason: 'all errors: $messages\n${run.output}',
            );
            expect(
              messages.where(
                (message) => message.startsWith('tearDown failed:'),
              ),
              hasLength(1),
              reason: 'all errors: $messages\n${run.output}',
            );
            expect(
              messages.singleWhere(
                (message) => message.startsWith('setUp failed:'),
              ),
              contains('setUp boom'),
            );
            expect(
              messages.singleWhere(
                (message) => message.startsWith('tearDown failed:'),
              ),
              contains('tearDown boom'),
            );
          },
        );
      },
    );

    test(
      'reports assertion failures in setUp fixtures as failed not broken',
      () async {
        final run = await _runDropInSample(
          sampleName: 'fixture_error_setup_assert_sample.dart',
        );

        await harnessStep(
          'Verify setUp TestFailure writes failed fixture and matching global',
          () {
            _expectFixtureHookGlobalError(
              run,
              hookName: 'setUp',
              boomText: 'assert boom',
              expectBrokenFixture: true,
              expectedFixtureStatus: 'failed',
            );
          },
        );
      },
    );

    test(
      'reports nested group setUp fixture hook errors as global errors',
      () async {
        final run = await _runDropInSample(
          sampleName: 'fixture_error_nested_setup_sample.dart',
        );

        await harnessStep(
          'Verify nested setUp failure writes one global and a broken fixture',
          () {
            _expectFixtureHookGlobalError(
              run,
              hookName: 'setUp',
              boomText: 'nested setUp boom',
              expectBrokenFixture: true,
            );
            expect(run.resultFiles, isNotEmpty, reason: run.output);
            final result = run.results.single;
            expect(result['titlePath'], const [
              'test',
              'sample_test.dart',
              'outer group',
              'nested group',
            ]);
          },
        );
      },
    );

    test(
      'writes exactly one globals error for a single failing setUp hook',
      () async {
        final run = await _runDropInSample(
          sampleName: 'fixture_error_setup_sample.dart',
        );

        await harnessStep(
          'Verify single-hook setUp failure produces exactly one globals error',
          () {
            _expectFixtureHookGlobalError(
              run,
              hookName: 'setUp',
              boomText: 'setUp boom',
              expectBrokenFixture: true,
            );
            expect(
              _allGlobalErrors(run),
              hasLength(1),
              reason:
                  'single-hook sample must not emit extra globals\n'
                  '${run.output}',
            );
          },
        );
      },
    );

    test('does not wrap addTearDown throws as fixture hook globals', () async {
      final run = await _runDropInSample(
        sampleName: 'fixture_error_add_teardown_sample.dart',
      );

      await harnessStep(
        'Verify addTearDown failure breaks the test without fixture/global wrap',
        () {
          expect(
            run.exitCode,
            isNonZero,
            reason: 'sample must fail\n${run.output}',
          );
          expect(run.resultFiles, hasLength(1), reason: run.output);

          final result = run.results.single;
          expect(
            result['status'],
            anyOf('broken', 'failed'),
            reason: run.output,
          );
          expect(
            (result['statusDetails'] as Map<String, dynamic>)['message']
                as String?,
            contains('addTearDown boom'),
          );

          final fixtures = _allFixtures(run);
          expect(
            fixtures.any((fixture) => fixture['name'] == 'addTearDown'),
            isFalse,
            reason:
                'addTearDown must not appear as an Allure fixture\n'
                '${run.output}',
          );

          final messages = _allGlobalErrors(
            run,
          ).map((error) => error['message'] as String? ?? '').toList();
          expect(
            messages.any(
              (message) => message.startsWith('addTearDown failed:'),
            ),
            isFalse,
            reason:
                'addTearDown must not emit wrapped globals\n'
                'all errors: $messages\n${run.output}',
          );
        },
      );
    });

    test('marks the test broken when setUp fails before the body runs', () async {
      final run = await _runDropInSample(
        sampleName: 'fixture_error_setup_body_never_ran_sample.dart',
      );

      await harnessStep(
        'Verify setUp failure leaves a broken/failed result without body steps',
        () {
          _expectFixtureHookGlobalError(
            run,
            hookName: 'setUp',
            boomText: 'setUp boom',
            expectBrokenFixture: true,
          );
          expect(run.resultFiles, hasLength(1), reason: run.output);

          final result = run.results.single;
          expect(
            result['status'],
            anyOf('broken', 'failed'),
            reason: run.output,
          );
          expect(
            (result['statusDetails'] as Map<String, dynamic>)['message']
                as String?,
            contains('setUp boom'),
          );

          final steps = (result['steps'] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>();
          expect(
            steps.any(
              (step) =>
                  step['name'] == 'body ran' && step['status'] == 'passed',
            ),
            isFalse,
            reason: 'body step must not have run\n${run.output}',
          );
        },
      );
    });

    test(
      'does not duplicate setUp globals when installAllure combines with drop-in',
      () async {
        final run = await _runSampleFromDirectory(
          sampleDirectory: 'mixed_mode_samples',
          sampleName: 'install_plus_drop_in_setup_error_sample.dart',
        );

        await harnessStep(
          'Verify mixed-mode setUp failure emits exactly one matching global',
          () {
            _expectFixtureHookGlobalError(
              run,
              hookName: 'setUp',
              boomText: 'mixed setUp boom',
              expectBrokenFixture: true,
            );
            expect(
              _allGlobalErrors(run),
              hasLength(1),
              reason:
                  'install+drop-in must not double-emit globals\n'
                  '${run.output}',
            );
          },
        );
      },
    );

    test('reports async setUp fixture hook errors as global errors', () async {
      final run = await _runDropInSample(
        sampleName: 'fixture_error_async_setup_sample.dart',
      );

      await harnessStep(
        'Verify async setUp failure writes a broken fixture and one matching global',
        () {
          _expectFixtureHookGlobalError(
            run,
            hookName: 'setUp',
            boomText: 'async setUp boom',
            expectBrokenFixture: true,
          );
        },
      );
    });

    test(
      'falls back to setUp failed when the hook error has an empty message',
      () async {
        final run = await _runDropInSample(
          sampleName: 'fixture_error_empty_message_sample.dart',
        );

        await harnessStep(
          'Verify empty toString uses the setUp failed fallback global message',
          () {
            expect(
              run.exitCode,
              isNonZero,
              reason: 'sample must fail\n${run.output}',
            );
            final allErrors = _allGlobalErrors(run);
            final matching = allErrors
                .where(
                  (error) =>
                      (error['message'] as String? ?? '') == 'setUp failed',
                )
                .toList();
            expect(
              matching,
              hasLength(1),
              reason:
                  'expected exactly one global with message "setUp failed"\n'
                  'all errors: ${allErrors.map((error) => error['message']).toList()}\n'
                  '${run.output}',
            );
            expect(
              matching.single['trace'] as String?,
              contains('sample_test.dart'),
            );
          },
        );
      },
    );

    test(
      'propagates metadata from a failing before-hook onto the test result',
      () async {
        final run = await _runDropInSample(
          sampleName: 'fixture_error_setup_metadata_sample.dart',
        );

        await harnessStep(
          'Verify failing setUp still applies owner/description/parameter to the test',
          () {
            _expectFixtureHookGlobalError(
              run,
              hookName: 'setUp',
              boomText: 'metadata setUp boom',
              expectBrokenFixture: true,
            );
            expect(run.resultFiles, hasLength(1), reason: run.output);

            final result = run.results.single;
            // Documented product truth: metadata written in a failing setUp
            // still reaches the test result, matching successful setUp
            // fixture_metadata_sample behavior.
            expect(
              result['labels'],
              containsAll(<Map<String, String>>[
                {'name': 'owner', 'value': 'failing-setup-owner'},
              ]),
            );
            expect(result['description'], 'failing before fixture description');
            expect(
              result['parameters'],
              containsAll(<Map<String, String>>[
                {'name': 'failing-setup-param', 'value': 'before'},
              ]),
            );
          },
        );
      },
    );

    test(
      'still writes setUpAll global when the suite is selected via test plan',
      () async {
        final run = await _runDropInSample(
          sampleName: 'fixture_error_setup_all_test_plan_sample.dart',
          testPlanContents:
              '{"version":"1.0","tests":[{"selector":"test/sample_test.dart#selected under test plan with setUpAll fail"}]}',
        );

        await harnessStep(
          'Verify test-plan selection still emits setUpAll failed global',
          () {
            _expectFixtureHookGlobalError(
              run,
              hookName: 'setUpAll',
              boomText: 'setUpAll boom',
              expectBrokenFixture: false,
            );
          },
        );
      },
    );
  });
}

List<Map<String, dynamic>> _allFixtures(_RunSampleResult run) {
  return run.containers
      .expand(
        (container) => <dynamic>[
          ...(container['befores'] as List<dynamic>),
          ...(container['afters'] as List<dynamic>),
        ],
      )
      .cast<Map<String, dynamic>>()
      .toList();
}

List<Map<String, dynamic>> _allGlobalErrors(_RunSampleResult run) {
  final globalsFiles = run.producedFiles
      .where((file) => file.path.endsWith('-globals.json'))
      .toList();
  return globalsFiles.expand((file) {
    final globals = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return (globals['errors'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }).toList();
}

/// Asserts a drop-in fixture hook failure exits non-zero, optionally records a
/// broken/failed fixture of [hookName], and writes exactly one matching global
/// error with prefix `{hookName} failed:` plus [boomText] and sample_test.dart
/// in the trace.
void _expectFixtureHookGlobalError(
  _RunSampleResult run, {
  required String hookName,
  required String boomText,
  required bool expectBrokenFixture,
  String? expectedFixtureStatus,
}) {
  expect(run.exitCode, isNonZero, reason: 'sample must fail\n${run.output}');

  if (expectBrokenFixture) {
    final fixtures = _allFixtures(run);
    final hookFixtures = fixtures
        .where((fixture) => fixture['name'] == hookName)
        .toList();
    expect(
      hookFixtures,
      isNotEmpty,
      reason: 'expected $hookName fixture in containers\n${run.output}',
    );
    final statusMatcher = expectedFixtureStatus == null
        ? (String? status) => status == 'broken' || status == 'failed'
        : (String? status) => status == expectedFixtureStatus;
    expect(
      hookFixtures.any(
        (fixture) =>
            statusMatcher(fixture['status'] as String?) &&
            ((fixture['statusDetails'] as Map<String, dynamic>?)?['message']
                        as String? ??
                    '')
                .contains(boomText),
      ),
      isTrue,
      reason:
          'expected a '
          '${expectedFixtureStatus ?? 'broken/failed'} $hookName fixture '
          'containing $boomText\n${run.output}',
    );
  }

  final allErrors = _allGlobalErrors(run);
  expect(
    allErrors,
    isNotEmpty,
    reason: 'fixture hook errors must produce *-globals.json\n${run.output}',
  );

  final matchingErrors = allErrors
      .where(
        (error) =>
            (error['message'] as String? ?? '').startsWith('$hookName failed:'),
      )
      .toList();
  expect(
    matchingErrors,
    hasLength(1),
    reason:
        'expected exactly one global error starting with "$hookName failed:"\n'
        'all errors: ${allErrors.map((error) => error['message']).toList()}\n'
        '${run.output}',
  );
  expect(matchingErrors.single['message'] as String, contains(boomText));
  expect(
    matchingErrors.single['trace'] as String?,
    contains('sample_test.dart'),
  );
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
    expectedTitlePath ?? <String>['test', 'sample_test.dart'],
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
    ]),
  );
}

class _RunSampleResult {
  _RunSampleResult({
    required this.exitCode,
    required this.output,
    required this.resultsDir,
    required this.producedFiles,
    required this.resultFiles,
    required this.results,
    required this.containerFiles,
    required this.containers,
  });

  final int exitCode;
  final String output;
  final Directory resultsDir;
  final List<File> producedFiles;
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
  final commonsRoot = p.normalize(
    p.join(repoRoot.path, '..', 'allure_dart_commons'),
  );
  const pubEnvironment = <String, String>{
    'HOME': '/tmp/codex-home',
    'DART_SUPPRESS_ANALYTICS': 'true',
  };

  final sampleSource = File(
    p.join(repoRoot.path, 'test', 'e2e', sampleDirectory, sampleName),
  );
  final pubspecContents =
      '''
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

  final producedFiles = <File>[];
  final resultFiles = <File>[];
  final containerFiles = <File>[];
  final results = <Map<String, dynamic>>[];
  final containers = <Map<String, dynamic>>[];
  await harnessStep(
    'Read produced Allure result and container JSON files for assertions',
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
      containerFiles
        ..clear()
        ..addAll(
          producedFiles.where((file) => file.path.endsWith('-container.json')),
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
    resultsDir: project.resultsDir,
    producedFiles: producedFiles,
    resultFiles: resultFiles,
    results: results,
    containerFiles: containerFiles,
    containers: containers,
  );
}
