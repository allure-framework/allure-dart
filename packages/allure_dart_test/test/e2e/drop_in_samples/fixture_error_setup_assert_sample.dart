import 'package:allure_dart_test/test.dart';

void main() {
  setUp(() {
    fail('assert boom');
  });

  test('drop in setUp assert fixture error sample', () {
    expect(2 + 2, equals(4));
  });
}
