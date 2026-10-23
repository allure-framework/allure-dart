import 'package:allure_dart_test/test.dart';

void main() {
  setUp(() {
    // Assertion failure so the global error carries failed status plus
    // actual/expected extracted from the matcher result.
    expect('got', equals('want'));
  });

  test('drop in setUp assert fixture error sample', () {
    expect(2 + 2, equals(4));
  });
}
