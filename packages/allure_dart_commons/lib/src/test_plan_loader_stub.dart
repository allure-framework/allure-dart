import 'platform.dart';

/// Returns no test plan because browser runtimes cannot read local files.
String? loadTestPlanContents(String path) {
  allureLogWarning(
    'Allure: test plan files are not supported on this platform',
  );
  return null;
}
