/// Sample exercising nested groups and all four fixture hooks through the
/// Flutter drop-in import.
///
/// Mirrors `packages/allure_dart_test/test/e2e/drop_in_samples/group_hooks_sample.dart`
/// for the Flutter adapter. Named `*_sample.dart` instead of `*_test.dart` so
/// a default recursive `flutter test` run does not pick it up; it is run
/// explicitly by `test/e2e/flutter_adapter_e2e_test.dart`.
library;
import 'package:allure_flutter_test/flutter_test.dart';

void main() {
  var setUpAllCount = 0;
  var setUpCount = 0;
  var tearDownCount = 0;
  var tearDownAllCount = 0;

  setUpAll(() {
    setUpAllCount++;
  });

  tearDownAll(() {
    tearDownAllCount++;
    expect(tearDownAllCount, equals(1));
    expect(setUpAllCount, equals(1));
    expect(setUpCount, equals(1));
    expect(tearDownCount, equals(1));
  });

  group('parent widget group', () {
    setUp(() {
      setUpCount++;
    });

    tearDown(() {
      tearDownCount++;
    });

    testWidgets('nested testWidgets uses hooks', (tester) async {
      expect(setUpCount, equals(1));
      expect('allure', contains('all'));
    });
  });
}
