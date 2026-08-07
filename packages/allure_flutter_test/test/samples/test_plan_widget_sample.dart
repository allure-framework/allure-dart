/// Sample with two `testWidgets` declarations used to verify that an Allure
/// test plan excludes one of them before its body runs.
///
/// Named `*_sample.dart` instead of `*_test.dart` so a default recursive
/// `flutter test` run does not pick it up; it is run explicitly by
/// `test/e2e/flutter_adapter_e2e_test.dart`.
library;

import 'package:allure_flutter_test/flutter_test.dart';

void main() {
  testWidgets('selected by test plan', (tester) async {
    expect(1 + 1, equals(2));
  });

  testWidgets('excluded by test plan', (tester) async {
    expect(1 + 1, equals(2));
  });
}
