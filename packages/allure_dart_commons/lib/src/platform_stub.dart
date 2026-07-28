import 'dart:developer' as developer;

/// Whether this runtime can read and write local files.
bool get allureSupportsFilesystem => false;

/// Process environment variables.
///
/// Empty on browser platforms. Callers that need values must pass an explicit
/// environment map.
Map<String, String> get allureEnvironment => const <String, String>{};

/// Current working directory path.
///
/// Browser runtimes have no filesystem CWD; returns `.` as a stable placeholder.
String get allureCurrentDirectory => '.';

/// Host name used for automatic `host` labels.
String get allureLocalHostname => 'web';

/// Thread id used for automatic `thread` labels.
String get allureProcessThreadId => 'browser';

/// Writes an Allure diagnostic message without throwing.
void allureLogWarning(String message) {
  developer.log(message, name: 'allure');
}

/// Throws a descriptive error for filesystem operations on unsupported platforms.
Never allureUnsupportedFilesystem(String operation) {
  throw UnsupportedError(
    'Allure cannot $operation on this platform (no filesystem). '
    'Browser/web runtimes cannot use Platform.environment or dart:io file APIs. '
    'Pass an explicit environment map where supported, or run tests on the VM / '
    'desktop where Allure can write allure-results.',
  );
}
