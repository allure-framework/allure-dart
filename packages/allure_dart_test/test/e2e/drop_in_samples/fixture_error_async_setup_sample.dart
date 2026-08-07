import 'package:allure_dart_test/test.dart';

void main() {
  setUp(() async {
    await Future<void>.delayed(Duration.zero);
    throw StateError('async setUp boom');
  });

  test('drop in async setUp fixture error sample', () {
    expect(2 + 2, equals(4));
  });
}
