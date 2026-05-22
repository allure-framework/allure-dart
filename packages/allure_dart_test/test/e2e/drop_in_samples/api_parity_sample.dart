import 'dart:async';

import 'package:allure_dart_test/test.dart';

void main() {
  test('drop in api parity sample', () async {
    addTearDown(() {
      expect(2, greaterThan(1));
    });

    expect({'a': 1}, containsPair('a', equals(1)));
    await expectLater(Future<int>.value(3), completion(equals(3)));
    expect(Stream<int>.fromIterable(const [1, 2]),
        emitsInOrder([1, 2, emitsDone]));
    expect(() => throw StateError('boom'), throwsA(isA<StateError>()));
    printOnFailure('visible only on failure');
    registerException(StateError('ignored by parity sample'), StackTrace.empty);
  }, skip: false);
}
