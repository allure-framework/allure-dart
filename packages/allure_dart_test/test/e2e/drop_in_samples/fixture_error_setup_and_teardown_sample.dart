import 'package:allure_dart_test/test.dart';

void main() {
  setUp(() {
    throw StateError('setUp boom');
  });

  tearDown(() {
    throw StateError('tearDown boom');
  });

  test('drop in setUp and tearDown fixture error sample', () {
    expect(2 + 2, equals(4));
  });
}
