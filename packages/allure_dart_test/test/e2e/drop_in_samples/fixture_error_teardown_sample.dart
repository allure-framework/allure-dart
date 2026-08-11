import 'package:allure_dart_test/test.dart';

void main() {
  tearDown(() {
    throw StateError('tearDown boom');
  });

  test('drop in tearDown fixture error sample', () {
    expect(2 + 2, equals(4));
  });
}
