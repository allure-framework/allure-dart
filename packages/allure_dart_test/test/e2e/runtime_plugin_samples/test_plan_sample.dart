import 'package:allure_dart_test/allure_dart_test.dart';
import 'package:test/test.dart';

void main() {
  installAllure();

  test('selected by test plan', () {
    expect(1 + 1, equals(2));
  });

  test('excluded by test plan', () {
    expect(1 + 1, equals(2));
  });
}
