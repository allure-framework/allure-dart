import 'package:allure_dart_test/allure_dart_test.dart';

void main() {
  allureTest('broken sample', (_) async {
    throw StateError('boom');
  });
}
