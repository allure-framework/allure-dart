import 'package:allure_dart_test/allure_dart_test.dart';
import 'package:test/test.dart';

void main() {
  allureTest('failure sample', (allure) async {
    await allure.step('failing step', () async {
      await allure.textAttachment(
        name: 'pre-failure context',
        content: 'about to fail',
        extension: 'txt',
      );
      expect(1, 2);
    });
  });
}
