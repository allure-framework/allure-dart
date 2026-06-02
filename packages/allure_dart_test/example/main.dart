// Import Allure's package:test adapter to get reporting helpers in the test body.
import 'package:allure_dart_test/allure_dart_test.dart';

void main() {
  allureTest('basic passing test', (allure) async {
    await allure.step('perform assertion', () async {
      final answer = 40 + 2;
      if (answer != 42) {
        throw StateError('Expected 42, got $answer');
      }
    });

    await allure.textAttachment(
      name: 'debug-log',
      content: 'The answer was verified successfully.',
    );
  });
}
