import 'config.dart';
import 'platform.dart';

/// Returns no config because browser runtimes cannot load local config files.
AllureConfig loadConfigFromFilesystem({
  required String? explicitPath,
  required String baseDirectory,
}) {
  if (explicitPath != null && explicitPath.isNotEmpty) {
    allureLogWarning(
      'Allure: config files are not supported on this platform: $explicitPath',
    );
  }
  return AllureConfig.empty;
}
