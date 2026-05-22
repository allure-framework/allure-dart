import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:allure_dart_test/allure_dart_test.dart';

void main() {
  allureTest('prepared stream attachment sample', (allure) async {
    await allure.preparedAttachment(
      name: 'prepared evidence',
      type: 'text/plain',
      extension: 'txt',
      write: (attachment) async {
        await File(attachment.path).writeAsString('prepared evidence payload');
      },
    );

    await allure.streamAttachment(
      name: 'stream evidence',
      type: 'text/plain',
      extension: 'txt',
      content: Stream<List<int>>.fromIterable(<List<int>>[
        utf8.encode('stream '),
        utf8.encode('evidence payload'),
      ]),
    );
  });
}
