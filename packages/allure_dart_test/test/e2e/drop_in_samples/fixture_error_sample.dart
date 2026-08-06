import 'package:allure_dart_test/test.dart';

void main() {
  setUp(() {
    throw StateError('fixture boom');
  });

  test('drop in fixture error sample', () {
    expect(2 + 2, equals(4));
  });
}
