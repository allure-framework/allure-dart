import 'package:allure_dart_test/test.dart';

void main() {
  setUpAll(() {
    throw StateError('setUpAll boom');
  });

  test('drop in setUpAll fixture error sample', () {
    expect(2 + 2, equals(4));
  });
}
