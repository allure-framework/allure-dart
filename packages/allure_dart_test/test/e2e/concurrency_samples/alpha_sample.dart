import 'package:allure_dart_test/allure_dart_test.dart';
import 'package:test/test.dart';

void main() {
  installAllure();

  test('concurrency isolation sample alpha', () async {
    await label('sample', 'alpha');
    await step('alpha step', (_) async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await attachment(
        'alpha payload',
        'alpha-only-content',
        contentType: 'text/plain',
        fileExtension: 'txt',
      );
    });
  });
}
