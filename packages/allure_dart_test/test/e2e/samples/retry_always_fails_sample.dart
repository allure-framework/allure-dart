import 'package:allure_dart_test/allure_dart_test.dart';
import 'package:test/test.dart';

/// Always fails, forcing `package:test` to re-run it once via `retry: 1`.
/// The Allure result for the retried attempt is expected to carry a `retry`
/// parameter, per `buildPackageTestMetadata`'s `retryCount > 1` handling.
void main() {
  group('retry group', () {
    allureTest('retry sample always fails', (_) async {
      expect(1, equals(2));
    });
  }, retry: 1);
}
