import 'package:allure_dart_test/test.dart';

void main() {
  group('outer group', () {
    setUp(() {
      // Outer setUp succeeds; nested setUp fails.
    });

    group('nested group', () {
      setUp(() {
        throw StateError('nested setUp boom');
      });

      test('drop in nested setUp fixture error sample', () {
        expect(2 + 2, equals(4));
      });
    });
  });
}
