import 'package:allure_dart_test/test.dart';

void main() {
  setUp(() {
    throw StateError('beta setUp boom');
  });

  test('concurrency fixture error sample beta', () {
    expect(2 + 2, equals(4));
  });
}
