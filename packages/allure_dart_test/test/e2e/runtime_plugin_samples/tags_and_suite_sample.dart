import 'package:allure_dart_test/allure_dart_test.dart';
import 'package:test/test.dart';

void main() {
  installAllure();

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
