import 'dart:convert';

import 'package:allure_dart_commons/allure_dart_commons.dart';
import 'package:allure_dart_test/allure_dart_test.dart' show installAllure;
import 'package:test/test.dart';

/// Minimal 1x1 PNG used as fixture bytes for imagediff encoding tests.
final List<int> _tinyPng = base64.decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  installAllure();

  group('Allure image diff helpers', () {
    test('encodeAllurePngDataUrl prefixes base64 PNG bytes', () {
      final dataUrl = encodeAllurePngDataUrl(_tinyPng);

      expect(dataUrl, startsWith('data:image/png;base64,'));
      expect(
        base64.decode(dataUrl.substring('data:image/png;base64,'.length)),
        _tinyPng,
      );
    });

    test('buildAllureImageDiffJson emits expected/actual data URLs', () {
      final expected = List<int>.from(_tinyPng);
      final actual = <int>[..._tinyPng, 1];

      final decoded =
          jsonDecode(
                buildAllureImageDiffJson(expected: expected, actual: actual),
              )
              as Map<String, dynamic>;

      expect(decoded.keys, unorderedEquals(<String>['expected', 'actual']));
      expect(decoded['expected'], encodeAllurePngDataUrl(expected));
      expect(decoded['actual'], encodeAllurePngDataUrl(actual));
    });

    test('buildAllureImageDiffJson includes optional diff data URL', () {
      final expected = List<int>.from(_tinyPng);
      final actual = <int>[..._tinyPng, 1];
      final diff = <int>[..._tinyPng, 2];

      final decoded =
          jsonDecode(
                buildAllureImageDiffJson(
                  expected: expected,
                  actual: actual,
                  diff: diff,
                ),
              )
              as Map<String, dynamic>;

      expect(
        decoded.keys,
        unorderedEquals(<String>['expected', 'actual', 'diff']),
      );
      expect(decoded['diff'], encodeAllurePngDataUrl(diff));
    });

    test(
      'content type and extension match Allure visual comparison contract',
      () {
        expect(allureImageDiffContentType, 'application/vnd.allure.image.diff');
        expect(allureImageDiffExtension, 'imagediff');
      },
    );

    test(
      'attachImageDiff writes imagediff attachment on the current test',
      () async {
        await attachImageDiff(
          'manual-diff',
          expected: _tinyPng,
          actual: _tinyPng,
          diff: _tinyPng,
        );
      },
    );
  });
}
