import 'package:allure_dart_test/allure_dart_test.dart';

void main() {
  allureTest('extended metadata sample', (allure) async {
    await displayName('Readable extended metadata');
    await testCaseName('logical extended metadata');
    await statusDetails(
      known: true,
      muted: false,
      flaky: true,
      actual: 'actual-value',
      expected: 'expected-value',
    );
  });
}
