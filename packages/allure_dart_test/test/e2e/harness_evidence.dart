import 'dart:async';
import 'dart:io';

import 'package:allure_dart_test/allure_dart_test.dart' as allure;
import 'package:path/path.dart' as p;

class PreparedTestProject {
  const PreparedTestProject({
    required this.tempDir,
    required this.resultsDir,
    required this.sampleFile,
    required this.pubspecFile,
    this.testPlanFile,
  });

  final Directory tempDir;
  final Directory resultsDir;
  final File sampleFile;
  final File pubspecFile;
  final File? testPlanFile;
}

Future<T> harnessStep<T>(
  String name,
  FutureOr<T> Function() body,
) {
  return allure.step(name, (_) => body());
}

Future<void> attachText(String name, String content) {
  return allure.attachment(
    name,
    content,
    contentType: 'text/plain',
    fileExtension: 'txt',
  );
}

Future<void> attachFile(File file, {required Directory relativeTo}) {
  return allure.attachment(
    p.relative(file.path, from: relativeTo.path),
    file.readAsBytesSync(),
    contentType: _contentTypeForPath(file.path),
    fileExtension: _fileExtensionForPath(file.path),
  );
}

Future<void> attachProcessResult(String name, ProcessResult result) {
  return attachText(name, '''
exitCode: ${result.exitCode}

stdout:
${result.stdout}

stderr:
${result.stderr}
''');
}

Future<PreparedTestProject> prepareTestProject({
  required String tempPrefix,
  required File sampleSource,
  required String pubspecContents,
  String? testPlanContents,
}) {
  return allure.step('Prepare test project', (step) async {
    final tempDir = await Directory.systemTemp.createTemp(tempPrefix);
    final resultsDir = Directory(p.join(tempDir.path, 'allure-results'));
    final testDir = Directory(p.join(tempDir.path, 'test'));
    await testDir.create(recursive: true);

    final sampleFile = File(p.join(testDir.path, 'sample_test.dart'));
    final pubspecFile = File(p.join(tempDir.path, 'pubspec.yaml'));
    final testPlanFile = testPlanContents == null
        ? null
        : File(p.join(tempDir.path, 'testplan.json'));

    await sampleSource.copy(sampleFile.path);
    await pubspecFile.writeAsString(pubspecContents);
    final testPlan = testPlanContents;
    if (testPlanFile != null && testPlan != null) {
      await testPlanFile.writeAsString(testPlan);
    }

    await step.parameter('projectDirectory', tempDir.path);
    await step.parameter('resultsDirectory', resultsDir.path);
    await step.parameter('sourceSamplePath', sampleSource.path);

    for (final file in <File>[
      sampleFile,
      pubspecFile,
      if (testPlanFile != null) testPlanFile,
    ]) {
      await attachFile(file, relativeTo: tempDir);
    }

    return PreparedTestProject(
      tempDir: tempDir,
      resultsDir: resultsDir,
      sampleFile: sampleFile,
      pubspecFile: pubspecFile,
      testPlanFile: testPlanFile,
    );
  });
}

Future<ProcessResult> runProcessStep({
  required String executable,
  required List<String> arguments,
  required Directory workingDirectory,
  required Map<String, String> environment,
  Directory? producedResultsDirectory,
}) {
  final command = <String>[executable, ...arguments].join(' ');
  return allure.step('Run $command', (step) async {
    await step.parameter('workingDirectory', workingDirectory.path);
    for (final entry in _sortedEnvironmentEntries(environment)) {
      await step.parameter('env.${entry.key}', entry.value);
    }

    final result = await Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory.path,
      environment: environment,
    );
    await attachProcessResult('$command output', result);

    if (producedResultsDirectory != null) {
      for (final file in listProducedFiles(producedResultsDirectory)) {
        await attachFile(file, relativeTo: workingDirectory);
      }
    }

    return result;
  });
}

List<File> listProducedFiles(Directory directory) {
  if (!directory.existsSync()) {
    return const <File>[];
  }
  return directory.listSync(recursive: true).whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

List<MapEntry<String, String>> _sortedEnvironmentEntries(
  Map<String, String> environment,
) {
  return environment.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
}

String _contentTypeForPath(String path) {
  return switch (p.extension(path).toLowerCase()) {
    '.dart' => 'text/x-dart',
    '.json' => 'application/json',
    '.yaml' || '.yml' => 'text/yaml',
    '.txt' || '.log' => 'text/plain',
    '.properties' => 'text/plain',
    '.bin' => 'application/octet-stream',
    _ => 'application/octet-stream',
  };
}

String? _fileExtensionForPath(String path) {
  final extension = p.extension(path);
  if (extension.isEmpty) {
    return null;
  }
  return extension.substring(1);
}
