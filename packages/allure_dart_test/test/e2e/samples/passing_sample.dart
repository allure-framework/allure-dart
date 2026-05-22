import 'package:allure_dart_test/allure_dart_test.dart';

void main() {
  allureTest(
    'writes passed result with attachment',
    (allure) async {
      await allure.step('outer step', () async {
        await allure.step('inner step', () async {
          await allure.textAttachment(
            name: 'payload',
            content: '{"status":"ok"}',
            type: 'application/json',
            extension: 'json',
          );
        });
      });
    },
    labels: const [AllureLabel(name: 'framework', value: 'dart-test')],
    parameters: const [AllureParameter(name: 'env', value: 'e2e')],
    links: const [
      AllureLink(
        name: 'docs',
        type: 'custom',
        url: 'https://example.test/docs',
      ),
    ],
  );
}
