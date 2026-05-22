import 'package:allure_dart_test/allure_dart_test.dart';
import 'package:test/test.dart';

void main() {
  installAllure();

  test('runtime plugin skipped sample', () {
    markTestSkipped('covered elsewhere');
  });
}
