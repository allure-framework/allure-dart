import 'package:allure_dart_test/allure_dart_test.dart' as allure;
import 'package:allure_dart_test/test.dart';

void main() {
  setUp(() async {
    await allure.owner('failing-setup-owner');
    await allure.description('failing before fixture description');
    await allure.parameter('failing-setup-param', 'before');
    throw StateError('metadata setUp boom');
  });

  test('drop in setUp metadata then fail sample', () {
    expect(2 + 2, equals(4));
  });
}
