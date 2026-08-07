import 'package:allure_dart_test/test.dart';

void main() {
  test('drop in addTearDown error sample', () {
    addTearDown(() {
      throw StateError('addTearDown boom');
    });
    expect(2 + 2, equals(4));
  });
}
