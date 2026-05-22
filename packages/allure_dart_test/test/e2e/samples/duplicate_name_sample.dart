import 'package:allure_dart_test/allure_dart_test.dart';
import 'package:test/test.dart';

void main() {
  group('alpha', () {
    allureTest('shared name', (_) async {
      expect(2 + 2, equals(4));
    });
  });

  group('beta', () {
    allureTest('shared name', (_) async {
      expect(3 + 3, equals(6));
    });
  });
}
