import 'package:allure_dart_test/test.dart';

void main() {
  group('drop in skipped group', () {
    test('nested test in skipped group', () {
      fail('no');
    });
  }, skip: true);
}
