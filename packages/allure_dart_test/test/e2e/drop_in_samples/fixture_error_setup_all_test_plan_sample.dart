import 'package:allure_dart_test/test.dart';

void main() {
  setUpAll(() {
    throw StateError('setUpAll boom');
  });

  test('selected under test plan with setUpAll fail', () {
    expect(2 + 2, equals(4));
  });
}
