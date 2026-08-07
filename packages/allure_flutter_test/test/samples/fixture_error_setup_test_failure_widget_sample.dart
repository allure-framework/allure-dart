/// Sample whose `setUp` throws a [TestFailure] so the Flutter drop-in reports
/// a failed (not broken) fixture plus a matching global error.
///
/// Named `*_sample.dart` so a default recursive `flutter test` run does not
/// pick it up; run explicitly by `test/e2e/flutter_adapter_e2e_test.dart`.
library;

import 'package:allure_flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    throw TestFailure('setUp TestFailure boom');
  });

  testWidgets('flutter setUp TestFailure fixture error sample', (tester) async {
    expect(2 + 2, equals(4));
  });
}
