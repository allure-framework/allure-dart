import 'package:allure_dart_test/test.dart';

void main() {
  test('excluded by test plan @allure.id:77', () {
    expect(1 + 1, equals(3));
  });
}
