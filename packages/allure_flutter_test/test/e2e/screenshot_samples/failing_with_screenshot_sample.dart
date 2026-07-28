/// Sample `testWidgets` that pumps a widget and then fails, verifying the
/// opt-in auto screenshot-on-failure hook (enabled by this directory's
/// `flutter_test_config.dart`) attaches a PNG screenshot to the failed
/// Allure result.
///
/// Named `*_sample.dart` instead of `*_test.dart` so a default recursive
/// `flutter test` run does not pick it up; it is run explicitly by
/// `test/e2e/flutter_adapter_e2e_test.dart`.
import 'package:allure_flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

void main() {
  testWidgets('fails after pumping a widget', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(color: Color(0xFF00FF00)),
      ),
    );

    await step('verify a deliberately wrong expectation', (_) async {
      expect(find.text('never rendered'), findsOneWidget);
    });
  });
}
