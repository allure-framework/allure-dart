import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'config.dart';
import 'model.dart';
import 'utils.dart';

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

/// Writes Allure result files and attachments to a results directory.
class AllureResultsWriter {
  /// Creates a writer for [outputDirectory] or `ALLURE_RESULTS_DIR`.
  AllureResultsWriter({
    String? outputDirectory,
    Uuid? uuid,
    AllureConfig? config,
  })  : _outputDirectory = Directory(
          outputDirectory ??
              Platform.environment['ALLURE_RESULTS_DIR'] ??
              (config ?? AllureConfig.load()).resultsDirectory ??
              'allure-results',
        ),
        _uuid = uuid ?? const Uuid();

  final Directory _outputDirectory;
  final Uuid _uuid;

  /// Ensures the output directory exists.
  Future<void> ensureInitialized() async {
    if (!_outputDirectory.existsSync()) {
      await _outputDirectory.create(recursive: true);
    }
  }

  /// Writes a test result JSON file.
  Future<void> writeTestResult(AllureTestResult result) async {
    await ensureInitialized();
    final file =
        File(p.join(_outputDirectory.path, '${result.uuid}-result.json'));
    await _writeStringAtomically(
      file,
      const JsonEncoder.withIndent('  ').convert(result.toJson()),
    );
  }

  /// Writes a test result container JSON file.
  Future<void> writeContainer(AllureTestResultContainer container) async {
    await ensureInitialized();
    final file =
        File(p.join(_outputDirectory.path, '${container.uuid}-container.json'));
    await _writeStringAtomically(
      file,
      const JsonEncoder.withIndent('  ').convert(container.toJson()),
    );
  }

  /// Writes an attachment from in-memory [content].
  Future<AllureAttachment> writeAttachment({
    required String name,
    required List<int> content,
    String? type,
    String? fileExtension,
    String? originalPath,
  }) async {
    await ensureInitialized();
    final extension = deriveAttachmentExtension(
      fileExtension: fileExtension,
      originalPath: originalPath,
      contentType: type,
    );
    final source = '${_uuid.v4()}-attachment${extension ?? ''}';
    final file = File(p.join(_outputDirectory.path, source));
    await _writeBytesAtomically(file, content);
    return AllureAttachment(
      name: name,
      source: source,
      type: type,
      size: content.length,
    );
  }

  /// Writes an attachment by reading bytes from [path].
  Future<AllureAttachment> writeAttachmentFromPath({
    required String name,
    required String path,
    String? type,
    String? fileExtension,
  }) async {
    await ensureInitialized();
    final bytes = await File(path).readAsBytes();
    return writeAttachment(
      name: name,
      content: bytes,
      type: type,
      fileExtension: fileExtension,
      originalPath: path,
    );
  }

  /// Reserves temporary and final paths for a streamed or custom attachment.
  Future<AllurePreparedAttachment> prepareAttachment({
    required String name,
    String? type,
    String? fileExtension,
    String? originalPath,
  }) async {
    await ensureInitialized();
    final extension = deriveAttachmentExtension(
      fileExtension: fileExtension,
      originalPath: originalPath,
      contentType: type,
    );
    final source = '${_uuid.v4()}-attachment${extension ?? ''}';
    final target = File(p.join(_outputDirectory.path, source));
    final temporary = _temporaryFileFor(target);
    return AllurePreparedAttachment(
      name: name,
      source: source,
      path: temporary.path,
      finalPath: target.path,
      type: type,
    );
  }

  /// Writes content into a prepared attachment and publishes it atomically.
  Future<AllureAttachment> writePreparedAttachment(
    AllurePreparedAttachment prepared,
    Future<void> Function(String path) write,
  ) async {
    await ensureInitialized();
    final target = File(prepared.finalPath);
    final temporary = File(prepared.path);
    await write(temporary.path);
    final size = await temporary.length();
    await _replaceFile(temporary, target);
    return AllureAttachment(
      name: prepared.name,
      source: prepared.source,
      type: prepared.type,
      size: size,
    );
  }

  /// Writes an attachment from a byte stream.
  Future<AllureAttachment> writeAttachmentStream({
    required String name,
    required Stream<List<int>> content,
    String? type,
    String? fileExtension,
    String? originalPath,
  }) async {
    final prepared = await prepareAttachment(
      name: name,
      type: type,
      fileExtension: fileExtension,
      originalPath: originalPath,
    );
    return writePreparedAttachment(
      prepared,
      (path) async {
        final file = File(path);
        final sink = file.openWrite();
        try {
          await for (final chunk in content) {
            sink.add(chunk);
          }
        } finally {
          await sink.close();
        }
      },
    );
  }

  /// Writes run-level global data.
  Future<void> writeGlobals(AllureGlobals globals) async {
    await ensureInitialized();
    final file =
        File(p.join(_outputDirectory.path, '${_uuid.v4()}-globals.json'));
    await _writeStringAtomically(
      file,
      const JsonEncoder.withIndent('  ').convert(globals.toJson()),
    );
  }

  /// Writes Allure environment properties.
  Future<void> writeEnvironmentInfo(AllureEnvironmentInfo info) async {
    await ensureInitialized();
    final file = File(p.join(_outputDirectory.path, 'environment.properties'));
    await _writeStringAtomically(file, stringifyEnvironmentInfo(info));
  }

  /// Writes Allure category definitions.
  Future<void> writeCategoriesDefinitions(
    List<AllureCategory> categories,
  ) async {
    await ensureInitialized();
    final file = File(p.join(_outputDirectory.path, 'categories.json'));
    await _writeStringAtomically(
      file,
      const JsonEncoder.withIndent('  ').convert(
        categories.map((category) => category.toJson()).toList(),
      ),
    );
  }

  /// Writes Allure executor metadata.
  Future<void> writeExecutorInfo(AllureExecutorInfo info) async {
    await ensureInitialized();
    final file = File(p.join(_outputDirectory.path, 'executor.json'));
    await _writeStringAtomically(
      file,
      const JsonEncoder.withIndent('  ').convert(info.toJson()),
    );
  }

  Future<void> _writeStringAtomically(File file, String content) {
    return _writeBytesAtomically(file, utf8.encode(content));
  }

  Future<void> _writeBytesAtomically(File file, List<int> content) async {
    final temporary = _temporaryFileFor(file);
    await temporary.writeAsBytes(content);
    await _replaceFile(temporary, file);
  }

  File _temporaryFileFor(File file) {
    return File('${file.path}.tmp-${_uuid.v4()}');
  }

  Future<void> _replaceFile(File temporary, File target) async {
    if (target.existsSync()) {
      await target.delete();
    }
    await temporary.rename(target.path);
  }
}
