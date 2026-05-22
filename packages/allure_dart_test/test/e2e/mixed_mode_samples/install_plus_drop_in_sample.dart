import 'package:allure_dart_test/allure_dart_test.dart';
import 'package:allure_dart_test/test.dart';

void main() {
  installAllure();

  test('install plus drop in sample', () {
    expect('allure', startsWith('all'));
  });
}
