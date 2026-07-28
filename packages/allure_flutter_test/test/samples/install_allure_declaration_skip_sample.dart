// Documents the `installAllure()` + declaration-skip footgun for Flutter:
// the runtime plugin schedules and finishes a result from a global
// `setUp`/`tearDown` pair, but `flutter_test`'s own declaration-time
// `skip: true` never runs `setUp`/`tearDown` for a skipped test. With plain
// `installAllure()` and the original `flutter_test` imports (no drop-in),
// this test therefore writes NO Allure result at all — see the "Skip
// Semantics" section of `packages/allure_flutter_test/README.md` for the
// runtime self-skip alternative that still produces a skipped result.
//
// Named `*_sample.dart` instead of `*_test.dart` so a default recursive
// `flutter test` run does not pick it up; it is run explicitly by
// `test/e2e/flutter_adapter_e2e_test.dart`.
import 'package:allure_flutter_test/allure_flutter_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  installAllure();

  testWidgets('declaration skip with installAllure only', (tester) async {
    fail('no');
  }, skip: true);
}
