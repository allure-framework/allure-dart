import 'package:allure_dart_test/test.dart';

void main() {
  tearDownAll(() {
    throw StateError('tearDownAll boom');
  });

  test('drop in tearDownAll fixture error sample', () {
    expect(2 + 2, equals(4));
  });
}
