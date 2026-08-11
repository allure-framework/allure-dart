import 'package:allure_dart_test/allure_dart_test.dart' as allure;
import 'package:allure_dart_test/test.dart';

void main() {
  setUp(() {
    throw StateError('setUp boom');
  });

  test('drop in setUp body never ran sample', () async {
    await allure.step('body ran', (_) async {});
    expect(2 + 2, equals(4));
  });
}
