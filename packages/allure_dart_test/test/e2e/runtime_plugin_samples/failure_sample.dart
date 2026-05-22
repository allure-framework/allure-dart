import 'package:allure_dart_test/allure_dart_test.dart';
import 'package:test/test.dart';

void main() {
  installAllure();

  test('runtime plugin failure sample', () {
    expect(1, 2);
  });
}
