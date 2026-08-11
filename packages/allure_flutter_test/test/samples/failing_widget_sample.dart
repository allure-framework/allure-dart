/// Sample `testWidgets` that is intentionally expected to fail.
///
/// This file demonstrates Allure "failed" status reporting for the Flutter
/// drop-in adapter. It is named `*_sample.dart` instead of `*_test.dart`, so
/// a default recursive `flutter test` run does not pick it up and the
/// package smoke suite stays green. This mirrors the `*_sample.dart`
/// convention used by `packages/allure_dart_test/test/e2e/samples`, whose
/// samples are run explicitly by a subprocess-based e2e harness.
///
/// This sample is run by the equivalent subprocess-based e2e harness for
/// this package, `test/e2e/flutter_adapter_e2e_test.dart`, which asserts the
/// failed-status behavior automatically. It can also be verified manually:
///
/// ```sh
/// flutter test test/samples/failing_widget_sample.dart
/// ```
///
/// The command above is expected to exit non-zero, and the generated
/// `allure-results/*-result.json` for "intentionally fails" is expected to
/// have `"status": "failed"`.
library;

import 'package:allure_flutter_test/flutter_test.dart';

void main() {
  testWidgets('intentionally fails', (tester) async {
    await step('verify a deliberately wrong expectation', (_) async {
      expect(find.text('never rendered'), findsOneWidget);
    });
  });
}
