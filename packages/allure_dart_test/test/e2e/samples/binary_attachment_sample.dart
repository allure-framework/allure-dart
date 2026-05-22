import 'dart:convert';

import 'package:allure_dart_test/allure_dart_test.dart';

void main() {
  allureTest('binary attachment sample', (allure) async {
    await allure.attachment(
      name: 'bytes',
      type: 'application/octet-stream',
      content: utf8.encode('hello-bytes'),
      extension: 'bin',
    );
  });
}
