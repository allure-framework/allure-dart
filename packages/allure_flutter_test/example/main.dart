// Import Allure's drop-in flutter_test API instead of package:flutter_test/flutter_test.dart.
import 'package:allure_flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

void main() {
  testWidgets('renders sample text', (tester) async {
    await step('render sample widget', (_) async {
      await tester.pumpWidget(
        const Text('Allure Flutter example', textDirection: TextDirection.ltr),
      );

      expect(find.text('Allure Flutter example'), findsOneWidget);
    });
  });
}
