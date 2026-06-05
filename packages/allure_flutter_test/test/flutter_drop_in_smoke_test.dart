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
        .map((file) =>
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)
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
                <String>{'compact', 'expanded'}
                    .contains(parameter['value'] as String?),
          ),
        ),
      );
    }
  });

  group('drop-in smoke', () {
    test('supports plain flutter_test declarations', () {
      expect(2 + 2, equals(4));
    });

    testWidgets(
      'wraps testWidgets variants',
      (tester) async {
        expect(find.text('missing'), findsNothing);
      },
      variant: ValueVariant<String>(<String>{'compact', 'expanded'}),
    );

    testWidgets('records widget expectations', (tester) async {
      await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: Text('hello'),
      ));

      expect(find.text('hello'), findsOneWidget);
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
