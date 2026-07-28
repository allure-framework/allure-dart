import 'dart:io';

/// Whether this runtime can read and write local files.
bool get allureSupportsFilesystem => true;

/// Process environment variables.
Map<String, String> get allureEnvironment => Platform.environment;

/// Current working directory path.
String get allureCurrentDirectory => Directory.current.path;

/// Host name used for automatic `host` labels.
String get allureLocalHostname => Platform.localHostname;

/// Thread id used for automatic `thread` labels.
String get allureProcessThreadId => 'pid-$pid';

/// Writes an Allure diagnostic message without throwing.
void allureLogWarning(String message) {
  stderr.writeln(message);
}

/// Throws a descriptive error for filesystem operations on unsupported platforms.
///
/// On IO platforms this should not be reached; it remains for API parity.
Never allureUnsupportedFilesystem(String operation) {
  throw UnsupportedError(
    'Allure cannot $operation on this platform (no filesystem).',
  );
}
