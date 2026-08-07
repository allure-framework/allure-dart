import 'package:allure_dart_test/test.dart';

void main() {
  setUp(() {
    throw StateError('alpha setUp boom');
  });

  test('concurrency fixture error sample alpha', () {
    expect(2 + 2, equals(4));
  });
}
