import 'dart:async';

import 'package:uuid/uuid.dart';

import 'config.dart';
import 'model.dart';
import 'platform.dart';

/// Prepared attachment file paths reserved before content is written.
class AllurePreparedAttachment {
  /// Creates prepared attachment metadata.
  const AllurePreparedAttachment({
    required this.name,
    required this.source,
    required this.path,
    required this.finalPath,
    this.type,
  });

  /// Display name of the attachment.
  final String name;

  /// Final attachment file name inside the results directory.
  final String source;

  /// Temporary filesystem path the producer must write.
  final String path;

  /// Final filesystem path where the attachment will be moved.
  final String finalPath;

  /// MIME type of the attachment, when known.
  final String? type;
}

/// Browser-safe writer that fails with an Allure-specific message.
///
/// Construction is allowed so libraries can load on web. The first write or
/// initialization attempt explains that filesystem results are unavailable.
class AllureResultsWriter {
  /// Creates a writer. [outputDirectory], [uuid], and [config] are accepted for
  /// API parity with the IO writer and ignored on browser platforms.
  AllureResultsWriter({
    String? outputDirectory,
    Uuid? uuid,
    AllureConfig? config,
  });

  Never _unsupported(String operation) =>
      allureUnsupportedFilesystem(operation);

  /// Ensures the output directory exists.
  Future<void> ensureInitialized() async {
    _unsupported('initialize an allure-results directory');
  }

  /// Writes a test result JSON file.
  Future<void> writeTestResult(AllureTestResult result) async {
    _unsupported('write test results');
  }

  /// Writes a test result container JSON file.
  Future<void> writeContainer(AllureTestResultContainer container) async {
    _unsupported('write containers');
  }

  /// Writes an attachment from in-memory [content].
  Future<AllureAttachment> writeAttachment({
    required String name,
    required List<int> content,
    String? type,
    String? fileExtension,
    String? originalPath,
  }) async {
    _unsupported('write attachments');
  }

  /// Writes an attachment by reading bytes from [path].
  Future<AllureAttachment> writeAttachmentFromPath({
    required String name,
    required String path,
    String? type,
    String? fileExtension,
  }) async {
    _unsupported('write attachments from path');
  }

  /// Reserves temporary and final paths for a streamed or custom attachment.
  Future<AllurePreparedAttachment> prepareAttachment({
    required String name,
    String? type,
    String? fileExtension,
    String? originalPath,
  }) async {
    _unsupported('prepare attachments');
  }

  /// Writes content into a prepared attachment and publishes it atomically.
  Future<AllureAttachment> writePreparedAttachment(
    AllurePreparedAttachment prepared,
    Future<void> Function(String path) write,
  ) async {
    _unsupported('write prepared attachments');
  }

  /// Writes an attachment from a byte stream.
  Future<AllureAttachment> writeAttachmentStream({
    required String name,
    required Stream<List<int>> content,
    String? type,
    String? fileExtension,
    String? originalPath,
  }) async {
    _unsupported('write attachment streams');
  }

  /// Writes run-level global data.
  Future<void> writeGlobals(AllureGlobals globals) async {
    _unsupported('write globals');
  }

  /// Writes Allure environment properties.
  Future<void> writeEnvironmentInfo(AllureEnvironmentInfo info) async {
    _unsupported('write environment info');
  }

  /// Writes Allure category definitions.
  Future<void> writeCategoriesDefinitions(
    List<AllureCategory> categories,
  ) async {
    _unsupported('write categories');
  }

  /// Writes Allure executor metadata.
  Future<void> writeExecutorInfo(AllureExecutorInfo info) async {
    _unsupported('write executor info');
  }
}
