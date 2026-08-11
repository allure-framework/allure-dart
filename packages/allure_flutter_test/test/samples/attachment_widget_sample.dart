/// Sample `testWidgets` that records an attachment payload.
///
/// Named `*_sample.dart` instead of `*_test.dart` so a default recursive
/// `flutter test` run does not pick it up; it is run explicitly by
/// `test/e2e/flutter_adapter_e2e_test.dart`.
library;

import 'package:allure_flutter_test/flutter_test.dart';

void main() {
  testWidgets('records an attachment payload', (tester) async {
    // Allure attachments perform real file I/O, so the write must happen
    // inside `runAsync`: `testWidgets` otherwise runs on a fake async zone
    // where real I/O callbacks never get pumped and the test would hang.
    await tester.runAsync(() async {
      await step('produce attachment evidence', (_) async {
        await attachment(
          'widget payload',
          'flutter-widget-attachment-content',
          contentType: 'text/plain',
          fileExtension: 'txt',
        );
      });
    });
  });
}
