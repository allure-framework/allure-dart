/// Platform seams for VM and browser runtimes.
///
/// Prefer this library over direct `dart:io` usage so Allure packages can load
/// on browser platforms without hitting opaque `Platform._environment` errors.
library;

export 'platform_stub.dart' if (dart.library.io) 'platform_io.dart';
