import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'config.dart';
import 'model.dart';
import 'platform.dart';
import 'utils.dart';

/// Callback used to durably sync a staged temp file before publish.
typedef AllureDurableFileSync = Future<void> Function(String path);

/// Callback used to publish a staged temp file to its final path.
///
/// Tests may inject a failing publish to prove staged payloads are retained.
typedef AllureDurableFilePublish =
    Future<void> Function(String temporaryPath, String targetPath);

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
  ///
  /// [durableSync] and [publishFile] override the default durable flush and
  /// rename-publish steps. Tests may inject probes or failures; production
  /// leaves them `null`.
  AllureResultsWriter({
    String? outputDirectory,
    Uuid? uuid,
    AllureConfig? config,
    AllureDurableFileSync? durableSync,
    AllureDurableFilePublish? publishFile,
  }) : _outputDirectory = Directory(
         outputDirectory ??
             allureEnvironment['ALLURE_RESULTS_DIR'] ??
             (config ?? AllureConfig.load()).resultsDirectory ??
             'allure-results',
       ),
       _uuid = uuid ?? const Uuid(),
       _durableSync = durableSync ?? syncAllureFileDurably,
       _publishFile = publishFile;

  final Directory _outputDirectory;
  final Uuid _uuid;
  final AllureDurableFileSync _durableSync;
  final AllureDurableFilePublish? _publishFile;
  bool _initialized = false;

  /// Ensures the output directory exists.
  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }
    if (!_outputDirectory.existsSync()) {
      await _outputDirectory.create(recursive: true);
    }
    _initialized = true;
  }

  /// Writes a test result JSON file.
  Future<void> writeTestResult(AllureTestResult result) async {
    await ensureInitialized();
    final file = File(
      p.join(_outputDirectory.path, '${result.uuid}-result.json'),
    );
    await _writeStringAtomically(
      file,
      const JsonEncoder.withIndent('  ').convert(result.toJson()),
    );
  }

  /// Writes a test result container JSON file.
  Future<void> writeContainer(AllureTestResultContainer container) async {
    await ensureInitialized();
    final file = File(
      p.join(_outputDirectory.path, '${container.uuid}-container.json'),
    );
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
    var stagedCompletely = false;
    try {
      await write(temporary.path);
      final size = await temporary.length();
      await _durableSync(temporary.path);
      stagedCompletely = true;
      await _publishStagedFile(temporary, target);
      return AllureAttachment(
        name: prepared.name,
        source: prepared.source,
        type: prepared.type,
        size: size,
      );
    } catch (_) {
      // Keep a fully synced staging file so a failed publish cannot erase the
      // only remaining copy of the payload.
      if (!stagedCompletely) {
        await _deleteIfExists(temporary);
      }
      rethrow;
    }
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
    return writePreparedAttachment(prepared, (path) async {
      final file = File(path);
      final sink = file.openWrite();
      try {
        await for (final chunk in content) {
          sink.add(chunk);
        }
      } finally {
        await sink.close();
      }
    });
  }

  /// Writes run-level global data.
  Future<void> writeGlobals(AllureGlobals globals) async {
    await ensureInitialized();
    final file = File(
      p.join(_outputDirectory.path, '${_uuid.v4()}-globals.json'),
    );
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
      const JsonEncoder.withIndent(
        '  ',
      ).convert(categories.map((category) => category.toJson()).toList()),
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
    var stagedCompletely = false;
    try {
      final raf = await temporary.open(mode: FileMode.writeOnly);
      try {
        await raf.writeFrom(content);
        await raf.flush();
      } finally {
        await raf.close();
      }
      await _durableSync(temporary.path);
      stagedCompletely = true;
      await _publishStagedFile(temporary, file);
    } catch (_) {
      // Keep a fully synced staging file so a failed publish cannot erase the
      // only remaining copy of the payload.
      if (!stagedCompletely) {
        await _deleteIfExists(temporary);
      }
      rethrow;
    }
  }

  File _temporaryFileFor(File file) {
    // Stage in the results directory as a hidden *.tmp file so live readers can
    // ignore incomplete publishes.
    return File(p.join(file.parent.path, '.allure-write-${_uuid.v4()}.tmp'));
  }

  Future<void> _publishStagedFile(File temporary, File target) {
    final publishFile = _publishFile;
    if (publishFile != null) {
      return publishFile(temporary.path, target.path);
    }
    return _replaceFile(temporary, target);
  }

  /// Publishes [temporary] as [target], preferring atomic rename-over-replace.
  ///
  /// When rename-over-existing is unavailable (typical on Windows), the
  /// existing target is moved aside, then the staged file is renamed into
  /// place, then the backup is deleted. On failure the staged temp is kept so
  /// the new payload is not discarded after the old file was already moved.
  Future<void> _replaceFile(File temporary, File target) async {
    try {
      await temporary.rename(target.path);
      return;
    } on FileSystemException {
      // Fall through to the replace-existing path.
    }

    if (!target.existsSync()) {
      // No existing target to displace; retry once and keep the staging file
      // if publish still fails.
      await temporary.rename(target.path);
      return;
    }

    final backup = _temporaryFileFor(target);
    await target.rename(backup.path);
    try {
      await temporary.rename(target.path);
    } catch (_) {
      // Prefer restoring the previous target when the new publish failed.
      try {
        if (!target.existsSync() && backup.existsSync()) {
          await backup.rename(target.path);
        }
      } catch (_) {
        // Best-effort restore; staging file is still kept below.
      }
      // Do not delete [temporary]: after moving the old target aside it may be
      // the only complete copy of the new payload.
      rethrow;
    }
    await _deleteIfExists(backup);
  }

  Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup after a failed publish.
    }
  }
}

/// Durably syncs the file at [path] to stable storage before rename.
///
/// Uses `RandomAccessFile.flush` (Linux `fsync` / Windows `FlushFileBuffers`).
/// On macOS, follows with `fcntl(F_FULLSYNC)` when available, falling back to
/// flush alone if the full-sync call fails.
Future<void> syncAllureFileDurably(String path) async {
  final file = File(path);
  final raf = await file.open(mode: FileMode.append);
  try {
    await raf.flush();
  } finally {
    await raf.close();
  }

  if (Platform.isMacOS) {
    _tryMacFullSync(file);
  }
}

void _tryMacFullSync(File file) {
  try {
    final libc = DynamicLibrary.process();
    final open = libc
        .lookupFunction<
          Int32 Function(Pointer<Utf8>, Int32),
          int Function(Pointer<Utf8>, int)
        >('open');
    final fcntl = libc
        .lookupFunction<Int32 Function(Int32, Int32), int Function(int, int)>(
          'fcntl',
        );
    final close = libc.lookupFunction<Int32 Function(Int32), int Function(int)>(
      'close',
    );

    // From sys/fcntl.h on macOS.
    const oRdonly = 0x0000;
    const fFullSync = 51;

    final nativePath = file.path.toNativeUtf8();
    try {
      final fd = open(nativePath, oRdonly);
      if (fd < 0) {
        return;
      }
      try {
        fcntl(fd, fFullSync);
      } finally {
        close(fd);
      }
    } finally {
      malloc.free(nativePath);
    }
  } catch (_) {
    // Flush already completed; F_FULLSYNC is best-effort durability.
  }
}
