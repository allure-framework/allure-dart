import 'dart:convert';
import 'dart:io';

import 'package:allure_dart_test/allure_dart_test.dart' as allure;
import 'package:allure_dart_test/src/package_test_support.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  allure.installAllure();

  group('package test support', () {
    test('resolves package paths from package root', () async {
      await allure.description('''
Verifies that test file paths are resolved from the nearest Dart package root rather than from the process current directory.

The fixture package lives outside the current package directory, so a cwd-relative path would include parent traversals. The resolved Allure path should instead be package-root relative and use POSIX separators.
''');

      final fixture = _PackagePathFixture.create();
      addTearDown(fixture.dispose);

      late Map<String, String?> resolved;
      await allure.step('Resolve paths for an external package fixture',
          (_) async {
        resolved = <String, String?>{
          'currentDirectory': Directory.current.path,
          'fromUri': packageTestPathFromUri(fixture.testFile.uri),
          'fromFilePath': packageTestPathFromFilePath(fixture.testFile.path),
          'fromStackTrace': resolvePackageTestPathFromDeclaration(
            stackTrace: fixture.stackTrace,
          ),
        };
        await allure.attachment(
          'resolved package paths',
          const JsonEncoder.withIndent('  ').convert(resolved),
          contentType: 'application/json',
          fileExtension: 'json',
        );
      });

      await _verifyPath(
        'Verify file URI path is package-root relative',
        resolved['fromUri'],
      );
      await _verifyPath(
        'Verify file path is package-root relative',
        resolved['fromFilePath'],
      );
      await _verifyPath(
        'Verify stack trace skips adapter frames',
        resolved['fromStackTrace'],
      );
    });
  });
}

Future<void> _verifyPath(String name, String? actual) {
  return allure.step(name, (step) async {
    await step.parameter('actual', actual);
    expect(actual, 'test/features/login_test.dart');
    expect(actual, isNot(contains(r'\')));
  });
}

class _PackagePathFixture {
  _PackagePathFixture._({
    required this.root,
    required this.testFile,
    required this.adapterFile,
  });

  final Directory root;
  final File testFile;
  final File adapterFile;

  StackTrace get stackTrace => StackTrace.fromString('''
package:allure_dart_test/src/package_test_support.dart 1:1
${adapterFile.uri} 2:2
${testFile.uri} 3:3
''');

  static _PackagePathFixture create() {
    final root = Directory.systemTemp.createTempSync('allure_dart_path_');
    final packageRoot =
        Directory(p.join(root.path, 'workspace', 'packages', 'sample_app'))
          ..createSync(recursive: true);
    File(p.join(packageRoot.path, 'pubspec.yaml'))
      ..createSync(recursive: true)
      ..writeAsStringSync('name: sample_app\n');

    final testFile =
        File(p.join(packageRoot.path, 'test', 'features', 'login_test.dart'))
          ..createSync(recursive: true)
          ..writeAsStringSync('void main() {}\n');
    final adapterFile =
        File(p.join(packageRoot.path, 'lib', 'src', 'test_drop_in.dart'))
          ..createSync(recursive: true)
          ..writeAsStringSync('void adapter() {}\n');

    return _PackagePathFixture._(
      root: root,
      testFile: testFile,
      adapterFile: adapterFile,
    );
  }

  void dispose() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  }
}
