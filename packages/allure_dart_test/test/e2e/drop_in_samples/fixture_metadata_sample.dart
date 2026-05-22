import 'package:allure_dart_test/allure_dart_test.dart' as allure;
import 'package:allure_dart_test/test.dart';

void main() {
  setUp(() async {
    await allure.owner('setup-owner');
    await allure.description('before fixture description');
    await allure.parameter('setup-param', 'before');
  });

  tearDown(() async {
    await allure.description('after fixture description');
    await allure.parameter('teardown-param', 'after');
  });

  test('fixture metadata sample', () {
    expect(2 + 2, equals(4));
  });
}
