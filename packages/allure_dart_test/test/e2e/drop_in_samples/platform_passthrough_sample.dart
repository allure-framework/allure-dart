import 'package:allure_dart_test/test.dart';

void main() {
  test(
    'drop in platform passthrough sample',
    () {
      expect(1 + 1, equals(2));
    },
    testOn: 'vm',
    onPlatform: const <String, dynamic>{
      'browser': Timeout.factor(2),
    },
  );
}
