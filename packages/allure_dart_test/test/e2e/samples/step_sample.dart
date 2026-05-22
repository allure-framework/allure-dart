import 'package:allure_dart_test/allure_dart_test.dart';

void main() {
  allureTest('step sample', (allure) async {
    await allure.step('outer step', () async {
      await allure.step('inner step', () async {});
    });
  });
}
