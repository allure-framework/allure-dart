import 'dart:convert';
import 'dart:io';

import 'package:allure_flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

void main() {
  final resultsDir = Directory('allure-results');

  tearDownAll(() async {
    final resultFiles = resultsDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('-result.json'))
        .toList();

    expect(resultFiles, isNotEmpty);

    final results = resultFiles
        .map(
          (file) => jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
        )
        .toList();
    final smokeResults = results.where((result) {
      final name = result['name'] as String;
      return name == 'supports plain flutter_test declarations' ||
          name == 'records widget expectations' ||
          name.contains('wraps testWidgets variants');
    }).toList();

    expect(smokeResults, isNotEmpty);
    expect(
      smokeResults.every(
        (result) => _hasLabel(
          result['labels'] as List<dynamic>,
          name: 'module',
          value: 'allure_flutter_test',
        ),
      ),
      isTrue,
    );
    expect(
      smokeResults.any(
        (result) => _hasLabel(
          result['labels'] as List<dynamic>,
          name: 'framework',
          value: 'flutter-test',
        ),
      ),
      isTrue,
    );
    expect(smokeResults.every(_hasSteps), isTrue);
    expect(
      smokeResults.any(
        (result) =>
            (result['name'] as String).contains('(variant: compact)') ||
            (result['name'] as String).contains('(variant: expanded)'),
      ),
      isTrue,
    );
    final variantResults = smokeResults
        .where((result) => (result['name'] as String).contains('(variant:'))
        .toList();
    expect(variantResults, hasLength(2));
    for (final result in variantResults) {
      expect(result['testCaseName'], 'wraps testWidgets variants');
      expect(
        result['parameters'] as List<dynamic>,
        contains(
          predicate<Map<dynamic, dynamic>>(
            (parameter) =>
                parameter['name'] == 'variant' &&
                <String>{
                  'compact',
                  'expanded',
                }.contains(parameter['value'] as String?),
          ),
        ),
      );
    }

    final skippedResults = results.where(
      (result) => result['name'] == 'is skipped explicitly',
    );
    expect(skippedResults, hasLength(1));
    final skippedResult = skippedResults.single;
    expect(skippedResult['status'], 'skipped');
    expect(skippedResult['stage'], 'pending');

    final fixtureTestResults = results
        .where((result) => result['name'] == 'runs with setUp and tearDown')
        .toList();
    expect(fixtureTestResults, hasLength(1));
    final fixtureTestUuid = fixtureTestResults.single['uuid'] as String;

    final containerFiles = resultsDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('-container.json'))
        .toList();
    expect(containerFiles, isNotEmpty);
    final containers = containerFiles
        .map(
          (file) => jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
        )
        .toList();

    final fixtureContainers = containers
        .where(
          (container) => (container['children'] as List<dynamic>).contains(
            fixtureTestUuid,
          ),
        )
        .toList();
    expect(
      fixtureContainers,
      isNotEmpty,
      reason: 'expected at least one container linking to the fixture test',
    );
    final linkedBefores = fixtureContainers
        .expand((container) => container['befores'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final linkedAfters = fixtureContainers
        .expand((container) => container['afters'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(linkedBefores.any((fixture) => fixture['name'] == 'setUp'), isTrue);
    expect(
      linkedAfters.any((fixture) => fixture['name'] == 'tearDown'),
      isTrue,
    );
  });

  group('drop-in smoke', () {
    test('supports plain flutter_test declarations', () async {
      await step('verify plain flutter_test expectation', (_) async {
        expect(2 + 2, equals(4));
      });
    });

    testWidgets(
      'wraps testWidgets variants',
      (tester) async {
        await step('verify absent text is not found', (_) async {
          expect(find.text('missing'), findsNothing);
        });
      },
      variant: ValueVariant<String>(<String>{'compact', 'expanded'}),
    );

    testWidgets('records widget expectations', (tester) async {
      await step('render widget and verify text', (_) async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: Text('hello'),
          ),
        );

        expect(find.text('hello'), findsOneWidget);
      });
    });

    test('is skipped explicitly', () {
      fail('declaration-skipped test body must not run');
    }, skip: true);
  });

  group('fixture smoke', () {
    var setUpCalls = 0;
    var tearDownCalls = 0;

    setUp(() {
      setUpCalls++;
    });

    tearDown(() {
      tearDownCalls++;
    });

    test('runs with setUp and tearDown', () async {
      await step('verify fixtures ran before the test body', (_) async {
        expect(setUpCalls, equals(1));
        expect(tearDownCalls, equals(0));
      });
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
