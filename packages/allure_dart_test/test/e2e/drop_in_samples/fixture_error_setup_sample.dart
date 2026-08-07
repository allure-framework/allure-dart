import 'package:allure_dart_test/test.dart';

void main() {
  setUp(() {
    throw StateError('setUp boom');
  });

  test('drop in setUp fixture error sample', () {
    expect(2 + 2, equals(4));
  });
}
