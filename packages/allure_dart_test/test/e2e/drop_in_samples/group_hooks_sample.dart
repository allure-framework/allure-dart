import 'package:allure_dart_test/test.dart';

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

  group('parent group', () {
    setUp(() {
      setUpCount++;
    });

    tearDown(() {
      tearDownCount++;
    });

    test('nested test uses hooks', () async {
      await expectLater(Future<int>.value(42), completion(equals(42)));
      addTearDown(() {
        expect(true, isTrue);
      });
      pumpEventQueue();
      expect('allure', contains('all'));
    });
  });
}
