/// Always fails, forcing `flutter_test` to re-run it once via `retry: 1`.
///
/// Mirrors `packages/allure_dart_test/test/e2e/runtime_plugin_samples/retry_always_fails_sample.dart`
/// for the Flutter adapter. The Allure result for the retried attempt is
/// expected to carry a `retry` parameter, per `buildPackageTestMetadata`'s
/// `retryCount > 1` handling. Named `*_sample.dart` instead of `*_test.dart`
/// so a default recursive `flutter test` run does not pick it up; it is run
/// explicitly by `test/e2e/flutter_adapter_e2e_test.dart`.
library;

import 'package:allure_flutter_test/flutter_test.dart';

void main() {
  testWidgets('retry widget sample always fails', (tester) async {
    expect(1, equals(2));
  }, retry: 1);
}
