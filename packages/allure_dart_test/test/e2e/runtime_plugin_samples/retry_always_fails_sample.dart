import 'package:allure_dart_test/allure_dart_test.dart';
import 'package:test/test.dart';

void main() {
  installAllure();

  test(
    'runtime plugin retry sample',
    () {
      fail('always fails so package:test retries');
    },
    retry: 1,
  );
}
