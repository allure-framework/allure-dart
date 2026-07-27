/// Opt-in auto golden-diff attach hook for the Flutter Allure adapter.
///
/// Installed by `installAllure(autoAttachGoldenDiff: true)`. It wraps
/// `flutter_test`'s [ft.goldenFileComparator] with a delegating comparator
/// that attaches the actual rendered PNG (and, best-effort, the
/// [ft.LocalFileComparator] failure diff PNGs on disk) to the Allure test
/// result whenever a `matchesGoldenFile` comparison fails.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:allure_dart_commons/allure_dart_commons.dart';
import 'package:flutter_test/flutter_test.dart' as ft;

bool _installed = false;

/// Installs the golden-diff attach hook, once per process.
///
/// Safe to call more than once: only the first call registers the per-test
/// re-wrap hook. Each test `setUp` re-wraps when a project replaces
/// [ft.goldenFileComparator] after install (for example with a tolerance
/// comparator), so attachments keep working.
void installGoldenDiffHook() {
  if (!_installed) {
    _installed = true;
    ft.setUp(_ensureGoldenComparatorWrapped);
  }
  _ensureGoldenComparatorWrapped();
}

void _ensureGoldenComparatorWrapped() {
  if (ft.goldenFileComparator is _AllureGoldenFileComparator) {
    return;
  }
  ft.goldenFileComparator =
      _AllureGoldenFileComparator(ft.goldenFileComparator);
}

/// A [ft.GoldenFileComparator] that delegates to another comparator and
/// attaches evidence to the Allure test result on mismatch.
class _AllureGoldenFileComparator extends ft.GoldenFileComparator {
  _AllureGoldenFileComparator(this._delegate);

  final ft.GoldenFileComparator _delegate;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    try {
      final passed = await _delegate.compare(imageBytes, golden);
      if (!passed) {
        await _attachGoldenDiff(imageBytes, golden);
      }
      return passed;
    } catch (_) {
      // The delegate throws (rather than returning false) on a real pixel
      // mismatch, e.g. `LocalFileComparator`. Attach evidence, then let the
      // original exception continue to drive the test's failure status.
      await _attachGoldenDiff(imageBytes, golden);
      rethrow;
    }
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) {
    return _delegate.update(golden, imageBytes);
  }

  @override
  Uri getTestUri(Uri key, int? version) {
    return _delegate.getTestUri(key, version);
  }

  Future<void> _attachGoldenDiff(Uint8List imageBytes, Uri golden) async {
    try {
      await attachment(
        'golden-actual',
        imageBytes,
        contentType: 'image/png',
        fileExtension: 'png',
      );
      final delegate = _delegate;
      if (delegate is ft.LocalFileComparator) {
        await _attachLocalFailureFiles(delegate, golden);
      }
    } catch (_) {
      // Best-effort: never mask the original golden-file failure.
    }
  }

  /// Attaches the `failures/*.png` diff images that [ft.LocalFileComparator]
  /// writes to disk on a mismatch (master, test, masked diff, isolated
  /// diff), if present.
  Future<void> _attachLocalFailureFiles(
    ft.LocalFileComparator comparator,
    Uri golden,
  ) async {
    final fileName = golden.pathSegments.last;
    final dotIndex = fileName.lastIndexOf('.');
    final baseName = dotIndex <= 0 ? fileName : fileName.substring(0, dotIndex);

    for (final suffix in const [
      'masterImage',
      'testImage',
      'maskedDiff',
      'isolatedDiff',
    ]) {
      final file = File.fromUri(
        comparator.basedir.resolve('failures/${baseName}_$suffix.png'),
      );
      if (!await file.exists()) {
        continue;
      }
      await attachmentPath(
        'golden-$suffix',
        file.path,
        contentType: 'image/png',
        fileExtension: 'png',
      );
    }
  }
}
