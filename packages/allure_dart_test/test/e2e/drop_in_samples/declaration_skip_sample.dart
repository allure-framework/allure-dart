import 'package:allure_dart_test/test.dart';

void main() {
  test(
    'drop in declaration skip sample',
    () {
      fail('no');
    },
    skip: true,
  );
}
