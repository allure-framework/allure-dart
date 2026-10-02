import 'dart:io';

/// Installs a local Git pre-commit hook that runs `dart_pre_commit`.
///
/// Usage (from the repository root):
///
/// ```bash
/// dart run tool/setup_git_hooks.dart
/// ```
Future<void> main(List<String> arguments) async {
  final repoRoot = Directory.current;
  final gitDir = Directory('${repoRoot.path}/.git');
  if (!gitDir.existsSync()) {
    stderr.writeln(
      'No .git directory found. Run this from the repository root.',
    );
    exitCode = 1;
    return;
  }

  final preCommitHook = File('${gitDir.path}/hooks/pre-commit');
  await preCommitHook.parent.create(recursive: true);
  await preCommitHook.writeAsString('''
#!/bin/sh
# Installed by: dart run tool/setup_git_hooks.dart
# Formats staged Dart files via dart_pre_commit (see pubspec.yaml).
set -e
cd "\$(git rev-parse --show-toplevel)"
exec dart run dart_pre_commit
''');

  if (!Platform.isWindows) {
    final result = await Process.run('chmod', ['a+x', preCommitHook.path]);
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    if (result.exitCode != 0) {
      exitCode = result.exitCode;
      return;
    }
  }

  stdout.writeln('Installed Git pre-commit hook at ${preCommitHook.path}');
}
