import 'package:allure_dart_test/test.dart';

class EmptyMessageException implements Exception {
  @override
  String toString() => '';
}

void main() {
  setUp(() {
    throw EmptyMessageException();
  });

  test('drop in empty message setUp fixture error sample', () {
    expect(2 + 2, equals(4));
  });
}
