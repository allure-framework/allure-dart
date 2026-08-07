import 'package:allure_dart_test/allure_dart_test.dart';
import 'package:allure_dart_test/test.dart';

void main() {
  installAllure();

  setUp(() {
    throw StateError('mixed setUp boom');
  });

  test('install plus drop in setUp error sample', () {
    expect(2 + 2, equals(4));
  });
}
