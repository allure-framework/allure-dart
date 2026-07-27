import 'package:allure_dart_commons/allure_dart_commons.dart';

bool _warningLogged = false;

/// Reports that golden diff files cannot be attached on this platform.
void installGoldenDiffHook() {
  if (_warningLogged) {
    return;
  }
  _warningLogged = true;
  allureLogWarning(
    'Allure: golden diff attachment requires local filesystem access.',
  );
}
