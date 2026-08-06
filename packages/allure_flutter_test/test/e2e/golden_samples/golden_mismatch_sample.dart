/// Sample `testWidgets` whose rendering intentionally mismatches a tiny
/// committed golden file, verifying the opt-in auto golden-diff attach hook
/// (enabled by this directory's `flutter_test_config.dart`) attaches the
/// actual rendered PNG (and, when available, the `LocalFileComparator`
/// failure diff PNGs) to the failed Allure result.
///
/// Named `*_sample.dart` instead of `*_test.dart` so a default recursive
/// `flutter test` run does not pick it up; it is run explicitly by
/// `test/e2e/flutter_adapter_e2e_test.dart`.
library;
import 'package:allure_flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

void main() {
  testWidgets('mismatches the committed golden file', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 40,
          height: 40,
          child: ColoredBox(color: Color(0xFF00FF00)),
        ),
      ),
    );

    await expectLater(
      find.byType(SizedBox),
      matchesGoldenFile('goldens/mismatch_golden.png'),
    );
  });
}
