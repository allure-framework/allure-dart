// Documents the `installAllure()` + declaration-skip footgun: the runtime
// plugin schedules and finishes a result from a global `setUp`/`tearDown`
// pair, but `package:test`'s own declaration-time `skip: true` never runs
// `setUp`/`tearDown` for a skipped test. With plain `installAllure()` and
// the original `package:test` imports (no drop-in), this test therefore
// writes NO Allure result at all — see the "Skip Semantics" section of
// `packages/allure_dart_test/README.md` for the runtime self-skip
// alternative that still produces a skipped result.
import 'package:allure_dart_test/allure_dart_test.dart';
import 'package:test/test.dart';

void main() {
  installAllure();

  test('declaration skip with installAllure only', () {
    fail('no');
  }, skip: true);
}
