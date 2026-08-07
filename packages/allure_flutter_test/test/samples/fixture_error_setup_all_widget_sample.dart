/// Sample whose `setUpAll` fixture throws so the Flutter drop-in reports a
/// global error without writing fixture containers.
///
/// Mirrors `packages/allure_dart_test/test/e2e/drop_in_samples/fixture_error_setup_all_sample.dart`.
/// Named `*_sample.dart` so a default recursive `flutter test` run does not
/// pick it up; run explicitly by `test/e2e/flutter_adapter_e2e_test.dart`.
library;

import 'package:allure_flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    throw StateError('setUpAll boom');
  });

  testWidgets('flutter setUpAll fixture error sample', (tester) async {
    expect(2 + 2, equals(4));
  });
}
