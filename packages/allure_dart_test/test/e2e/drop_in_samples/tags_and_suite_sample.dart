import 'package:allure_dart_test/test.dart';

void main() {
  group('outer group', () {
    group('inner group', () {
      group('deepest group', () {
        test('tagged nested test', () {
          expect(1 + 1, equals(2));
        }, tags: ['smoke']);
      });
    });
  });
}
