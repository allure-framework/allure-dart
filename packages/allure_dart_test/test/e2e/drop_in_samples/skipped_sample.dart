import 'package:allure_dart_test/test.dart';

void main() {
  test('drop in skipped sample', () {
    markTestSkipped('skip through drop-in import');
  });
}
