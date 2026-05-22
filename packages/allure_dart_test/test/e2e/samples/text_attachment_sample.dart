import 'package:allure_dart_test/allure_dart_test.dart';

void main() {
  allureTest('text attachment sample', (allure) async {
    await allure.step('step with text attachment', () async {
      await allure.textAttachment(
        name: 'payload',
        content: '{"status":"ok"}',
        type: 'application/json',
        extension: 'json',
      );
    });
  });
}
