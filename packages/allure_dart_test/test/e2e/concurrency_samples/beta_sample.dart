import 'package:allure_dart_test/allure_dart_test.dart';
import 'package:test/test.dart';

void main() {
  installAllure();

  test('concurrency isolation sample beta', () async {
    await label('sample', 'beta');
    await step('beta step', (_) async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await attachment(
        'beta payload',
        'beta-only-content',
        contentType: 'text/plain',
        fileExtension: 'txt',
      );
    });
  });
}
