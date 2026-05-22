import 'package:allure_dart_test/allure_dart_test.dart';

void main() {
  allureTest('allureTest plan sample', (_) async {
    throw StateError('body should not run when excluded by the test plan');
  });
}
