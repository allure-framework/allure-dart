import 'package:allure_dart_test/allure_dart_test.dart';
import 'package:test/test.dart';

void main() {
  installAllure();

  test('runtime api sample @allure.label.owner:alice', () async {
    await parameter('browser', 'chromium');
    await link(
      'https://example.test/BUG-1',
      name: 'bug',
      type: 'issue',
    );

    await step('outer step', (context) async {
      await context.parameter('attempt', 1);
      await attachment(
        'payload',
        '{"status":"ok"}',
        contentType: 'application/json',
        fileExtension: 'json',
      );
    });
  });
}
