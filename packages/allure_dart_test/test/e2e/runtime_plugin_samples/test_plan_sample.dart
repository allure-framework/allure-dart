import 'package:allure_dart_test/allure_dart_test.dart';
import 'package:test/test.dart';

void main() {
  installAllure();

  test('selected by test plan', () {
    expect(1 + 1, equals(2));
  });

  // Plain installAllure() cannot declaration-skip package:test bodies; the
  // excluded test still runs, but its Allure result is suppressed via the
  // ALLURE_TESTPLAN_SKIP label. Use the drop-in wrappers to skip bodies.
  test('excluded by test plan', () {
    expect(1 + 1, equals(2));
  });
}
