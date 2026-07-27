// Documents the Flutter drop-in group-skip tradeoff. Mirrors
// `packages/allure_dart_test/test/e2e/drop_in_samples/group_skip_sample.dart`
// for the Flutter adapter: a group-level `skip: true` is tracked on an
// internal registry only and is not forwarded to `flutter_test`'s own group
// skip. The nested `testWidgets` still runs through `flutter_test`'s normal
// scheduling and self-skips at runtime via `markTestSkipped`, so the group's
// `setUp` fixture MAY still run once per nested test even though the group
// itself is skipped — unlike a stock declaration group skip, which never
// runs the group's fixtures at all.
//
// Named `*_sample.dart` instead of `*_test.dart` so a default recursive
// `flutter test` run does not pick it up; it is run explicitly by
// `test/e2e/flutter_adapter_e2e_test.dart`.
import 'package:allure_flutter_test/flutter_test.dart';

void main() {
  group(
    'drop in skipped widget group',
    () {
      setUp(() {});

      testWidgets('nested testWidgets in skipped group', (tester) async {
        fail('no');
      });
    },
    skip: true,
  );
}
