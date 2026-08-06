/// Sample used to verify per-suite Allure evidence isolation under concurrent
/// `flutter test` execution.
///
/// Mirrors `packages/allure_dart_test/test/e2e/concurrency_samples/beta_sample.dart`
/// for the Flutter adapter. Named `*_sample.dart` instead of `*_test.dart` so
/// a default recursive `flutter test` run does not pick it up; it is run
/// explicitly (together with `concurrency_alpha_widget_sample.dart`) by
/// `test/e2e/flutter_adapter_e2e_test.dart`.
library;
import 'package:allure_flutter_test/flutter_test.dart';

void main() {
  testWidgets('concurrency isolation widget sample beta', (tester) async {
    await label('sample', 'beta');
    // Allure attachments perform real file I/O, so the write must happen
    // inside `runAsync`: `testWidgets` otherwise runs on a fake async zone
    // where real I/O callbacks never get pumped and the test would hang.
    await tester.runAsync(() async {
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
  });
}
