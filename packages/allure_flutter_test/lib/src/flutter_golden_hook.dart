/// Opt-in auto golden-diff attach hook for the Flutter Allure adapter.
///
/// Installed by `installAllure(autoAttachGoldenDiff: true)`. It wraps
/// `flutter_test`'s [ft.goldenFileComparator] with a delegating comparator
/// that attaches Allure visual-comparison evidence whenever a
/// `matchesGoldenFile` comparison fails.
///
/// Prefer a single `application/vnd.allure.image.diff` attachment when
/// [ft.LocalFileComparator] has written expected/actual/diff PNGs. Fall back
/// to separate PNG attachments when the full triad is unavailable.
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
  ft.goldenFileComparator = _AllureGoldenFileComparator(
    ft.goldenFileComparator,
  );
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
      final delegate = _delegate;
      if (delegate is ft.LocalFileComparator) {
        final attachedImageDiff = await _attachLocalImageDiff(
          delegate,
          golden,
          imageBytes,
        );
        if (attachedImageDiff) {
          return;
        }
        await _attachLocalFailureFiles(delegate, golden);
      }
      await attachment(
        'golden-actual',
        imageBytes,
        contentType: 'image/png',
        fileExtension: 'png',
      );
    } catch (_) {
      // Best-effort: never mask the original golden-file failure.
    }
  }

  /// Attaches an Allure imagediff when expected and actual PNGs exist.
  ///
  /// [ft.LocalFileComparator] writes `failures/*_masterImage.png` (expected)
  /// and `*_testImage.png` (actual). Same-size pixel mismatches may also
  /// write `*_maskedDiff.png` / `*_isolatedDiff.png` for the optional diff
  /// pane.
  Future<bool> _attachLocalImageDiff(
    ft.LocalFileComparator comparator,
    Uri golden,
    Uint8List imageBytes,
  ) async {
    final failureFiles = _localFailureFiles(comparator, golden);
    final expectedFile = failureFiles['masterImage'];
    final actualFile = failureFiles['testImage'];
    final maskedFile = failureFiles['maskedDiff'];
    final isolatedFile = failureFiles['isolatedDiff'];

    if (expectedFile == null || !await expectedFile.exists()) {
      return false;
    }

    final expectedBytes = await expectedFile.readAsBytes();
    final actualBytes = actualFile != null && await actualFile.exists()
        ? await actualFile.readAsBytes()
        : imageBytes;

    List<int>? diffBytes;
    for (final candidate in [maskedFile, isolatedFile]) {
      if (candidate != null && await candidate.exists()) {
        diffBytes = await candidate.readAsBytes();
        break;
      }
    }

    await attachImageDiff(
      'golden-diff',
      expected: expectedBytes,
      actual: actualBytes,
      diff: diffBytes,
    );
    return true;
  }

  /// Attaches the `failures/*.png` images when a full imagediff triad is
  /// unavailable (for example size-mismatch failures without diff PNGs).
  Future<void> _attachLocalFailureFiles(
    ft.LocalFileComparator comparator,
    Uri golden,
  ) async {
    for (final entry in _localFailureFiles(comparator, golden).entries) {
      final file = entry.value;
      if (file == null || !await file.exists()) {
        continue;
      }
      await attachmentPath(
        'golden-${entry.key}',
        file.path,
        contentType: 'image/png',
        fileExtension: 'png',
      );
    }
  }

  Map<String, File?> _localFailureFiles(
    ft.LocalFileComparator comparator,
    Uri golden,
  ) {
    final fileName = golden.pathSegments.last;
    final dotIndex = fileName.lastIndexOf('.');
    final baseName = dotIndex <= 0 ? fileName : fileName.substring(0, dotIndex);

    File? fileFor(String suffix) {
      return File.fromUri(
        comparator.basedir.resolve('failures/${baseName}_$suffix.png'),
      );
    }

    return <String, File?>{
      'masterImage': fileFor('masterImage'),
      'testImage': fileFor('testImage'),
      'maskedDiff': fileFor('maskedDiff'),
      'isolatedDiff': fileFor('isolatedDiff'),
    };
  }
}
