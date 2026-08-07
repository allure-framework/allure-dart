/// Sample whose async `setUp` fixture throws so the Flutter drop-in reports a
/// global error for asynchronous hook failures.
///
/// Named `*_sample.dart` so a default recursive `flutter test` run does not
/// pick it up; run explicitly by `test/e2e/flutter_adapter_e2e_test.dart`.
library;

import 'package:allure_flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    throw StateError('async setUp boom');
  });

  testWidgets('flutter async setUp fixture error sample', (tester) async {
    expect(2 + 2, equals(4));
  });
}
