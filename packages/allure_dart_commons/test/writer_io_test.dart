import 'dart:convert';
import 'dart:io';

import 'package:allure_dart_commons/allure_dart_commons.dart';
import 'package:allure_dart_test/allure_dart_test.dart' show installAllure;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  installAllure();

  group(
    'AllureResultsWriter durable atomic publishes',
    () {
      late Directory resultsDir;
      late List<String> syncedPaths;

      setUp(() async {
        resultsDir = await Directory.systemTemp.createTemp(
          'allure_dart_writer_atomic_',
        );
        syncedPaths = <String>[];
      });

      tearDown(() async {
        if (resultsDir.existsSync()) {
          await resultsDir.delete(recursive: true);
        }
      });

      AllureResultsWriter writerWithSyncProbe() {
        return AllureResultsWriter(
          outputDirectory: resultsDir.path,
          durableSync: (path) async {
            syncedPaths.add(path);
            await syncAllureFileDurably(path);
          },
        );
      }

      List<File> tmpFiles() {
        return resultsDir.listSync(followLinks: false).whereType<File>().where((
          file,
        ) {
          final name = p.basename(file.path);
          return name.startsWith('.allure-write-') && name.endsWith('.tmp');
        }).toList();
      }

      test(
        'writes test result and globals as final files only after durable sync',
        () async {
          final writer = writerWithSyncProbe();

          await writer.writeTestResult(
            AllureTestResult(
              uuid: 'test-uuid',
              name: 'atomic result',
              status: AllureStatus.passed,
              stage: AllureStage.finished,
            ),
          );
          await writer.writeGlobals(
            const AllureGlobals(
              errors: <AllureGlobalError>[
                AllureGlobalError(timestamp: 1, message: 'global boom'),
              ],
            ),
          );

          final resultFile = File(
            p.join(resultsDir.path, 'test-uuid-result.json'),
          );
          expect(resultFile.existsSync(), isTrue);
          final decoded =
              jsonDecode(resultFile.readAsStringSync()) as Map<String, dynamic>;
          expect(decoded['name'], 'atomic result');
          expect(decoded['status'], 'passed');

          final globalsFiles = resultsDir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('-globals.json'))
              .toList();
          expect(globalsFiles, hasLength(1));
          final globals =
              jsonDecode(globalsFiles.single.readAsStringSync())
                  as Map<String, dynamic>;
          expect(
            (globals['errors'] as List<dynamic>).single['message'],
            'global boom',
          );

          expect(tmpFiles(), isEmpty);
          expect(syncedPaths, hasLength(2));
          expect(
            syncedPaths.every((path) {
              final name = p.basename(path);
              return name.startsWith('.allure-write-') && name.endsWith('.tmp');
            }),
            isTrue,
            reason: 'durable sync must target staged .allure-write-*.tmp files',
          );
        },
      );

      test('overwrites sidecar files without leaving temp leftovers', () async {
        final writer = writerWithSyncProbe();

        await writer.writeCategoriesDefinitions(const <AllureCategory>[
          AllureCategory(name: 'first'),
        ]);
        await writer.writeCategoriesDefinitions(const <AllureCategory>[
          AllureCategory(name: 'second'),
        ]);
        await writer.writeExecutorInfo(
          const AllureExecutorInfo(name: 'first-executor'),
        );
        await writer.writeExecutorInfo(
          const AllureExecutorInfo(name: 'second-executor'),
        );

        final categories =
            jsonDecode(
                  File(
                    p.join(resultsDir.path, 'categories.json'),
                  ).readAsStringSync(),
                )
                as List<dynamic>;
        expect(categories.single['name'], 'second');

        final executor =
            jsonDecode(
                  File(
                    p.join(resultsDir.path, 'executor.json'),
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        expect(executor['name'], 'second-executor');

        expect(tmpFiles(), isEmpty);
        expect(syncedPaths, hasLength(4));
      });

      test(
        'publishes prepared and streamed attachments after durable sync',
        () async {
          final writer = writerWithSyncProbe();

          final preparedAttachment = await writer.writePreparedAttachment(
            await writer.prepareAttachment(
              name: 'prepared',
              type: 'text/plain',
              fileExtension: 'txt',
            ),
            (path) async {
              await File(path).writeAsString('prepared-body');
            },
          );
          expect(preparedAttachment.source, isNot(contains('.allure-write-')));
          expect(preparedAttachment.source, isNot(endsWith('.tmp')));

          final streamAttachment = await writer.writeAttachmentStream(
            name: 'streamed',
            content: Stream<List<int>>.fromIterable([
              utf8.encode('stream-'),
              utf8.encode('body'),
            ]),
            type: 'text/plain',
            fileExtension: 'txt',
          );
          expect(streamAttachment.source, isNot(contains('.allure-write-')));
          expect(streamAttachment.source, isNot(endsWith('.tmp')));

          final preparedFile = File(
            p.join(resultsDir.path, preparedAttachment.source),
          );
          final streamFile = File(
            p.join(resultsDir.path, streamAttachment.source),
          );
          expect(preparedFile.readAsStringSync(), 'prepared-body');
          expect(streamFile.readAsStringSync(), 'stream-body');
          expect(tmpFiles(), isEmpty);
          expect(syncedPaths, hasLength(2));
        },
      );

      test('invokes durable sync once per byte attachment publish', () async {
        final writer = writerWithSyncProbe();

        await writer.writeAttachment(
          name: 'bytes',
          content: utf8.encode('payload'),
          type: 'text/plain',
          fileExtension: 'txt',
        );

        expect(syncedPaths, hasLength(1));
        expect(tmpFiles(), isEmpty);
        expect(
          resultsDir.listSync().whereType<File>().any(
            (file) => p.basename(file.path).endsWith('-attachment.txt'),
          ),
          isTrue,
        );
      });

      test(
        'keeps staged payload when publish fails after durable sync',
        () async {
          final seed = AllureResultsWriter(outputDirectory: resultsDir.path);
          await seed.writeCategoriesDefinitions(const <AllureCategory>[
            AllureCategory(name: 'first'),
          ]);

          final writer = AllureResultsWriter(
            outputDirectory: resultsDir.path,
            durableSync: (path) async {
              syncedPaths.add(path);
              await syncAllureFileDurably(path);
            },
            publishFile: (temporaryPath, targetPath) async {
              // Simulate the dangerous Windows overwrite window: existing
              // target is already gone, and renaming the staged file fails.
              final target = File(targetPath);
              if (target.existsSync()) {
                await target.delete();
              }
              throw const FileSystemException('simulated rename failure');
            },
          );

          await expectLater(
            writer.writeCategoriesDefinitions(const <AllureCategory>[
              AllureCategory(name: 'second'),
            ]),
            throwsA(isA<FileSystemException>()),
          );

          expect(syncedPaths, hasLength(1));
          final leftover = tmpFiles();
          expect(
            leftover,
            isNotEmpty,
            reason: 'fully synced staging file must survive publish failure',
          );
          expect(
            leftover.any(
              (file) => file.readAsStringSync().contains('"name": "second"'),
            ),
            isTrue,
            reason: 'staged temp must retain the new payload',
          );
        },
      );
    },
    skip: !allureSupportsFilesystem,
  );
}
