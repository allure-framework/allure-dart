import 'dart:convert';
import 'dart:io';

import 'package:allure_dart_commons/allure_dart_commons.dart';
import 'package:allure_dart_test/allure_dart_test.dart' show installAllure;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Error-shaped object with assertion fields for extraction tests.
class _AssertionLikeError implements Exception {
  _AssertionLikeError({
    required this.message,
    required this.actual,
    required this.expected,
  });

  final String message;
  final Object actual;
  final Object expected;

  @override
  String toString() => message;
}

/// Error-shaped object with an explicit `trace` field (allure-js style).
class _TracedError implements Exception {
  _TracedError({required this.message, required this.trace});

  final String message;
  final String trace;

  @override
  String toString() => message;
}

void main() {
  installAllure();

  late Directory resultsDir;
  late AllureLifecycle lifecycle;

  setUp(() async {
    resultsDir = await Directory.systemTemp.createTemp(
      'allure_dart_global_error_',
    );
    lifecycle = AllureLifecycle(
      writer: AllureResultsWriter(outputDirectory: resultsDir.path),
    );
    setGlobalTestRuntime(
      MessageTestRuntime(sink: lifecycle, contextResolver: () => null),
    );
  });

  tearDown(() async {
    setGlobalTestRuntime(const NoopTestRuntime());
    if (resultsDir.existsSync()) {
      await resultsDir.delete(recursive: true);
    }
  });

  Future<Map<String, dynamic>> readSingleGlobalError() async {
    final globalsFiles = resultsDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('-globals.json'))
        .toList();
    expect(globalsFiles, hasLength(1));
    final decoded =
        jsonDecode(globalsFiles.single.readAsStringSync())
            as Map<String, dynamic>;
    final errors = decoded['errors'] as List<dynamic>;
    expect(errors, hasLength(1));
    return errors.single as Map<String, dynamic>;
  }

  test(
    'globalError extracts status and details from an error object',
    () async {
      await globalError(
        error: _AssertionLikeError(
          message: 'values differ',
          actual: 'got',
          expected: 'want',
        ),
        stackTrace: StackTrace.current,
      );

      final error = await readSingleGlobalError();
      expect(error['status'], 'failed');
      expect(error['message'], 'values differ');
      expect(error['actual'], 'got');
      expect(error['expected'], 'want');
      expect(error['trace'], isA<String>());
      expect(error['timestamp'], isA<int>());
    },
  );

  test(
    'globalError uses explicit overrides over extracted error fields',
    () async {
      await globalError(
        error: _AssertionLikeError(
          message: 'values differ',
          actual: 'got',
          expected: 'want',
        ),
        status: AllureStatus.broken,
        message: 'override message',
        actual: 'override-actual',
        expected: 'override-expected',
      );

      final error = await readSingleGlobalError();
      expect(error['status'], 'broken');
      expect(error['message'], 'override message');
      expect(error['actual'], 'override-actual');
      expect(error['expected'], 'override-expected');
    },
  );

  test('writeGlobalError persists status with details', () async {
    await lifecycle.writeGlobalError(
      const AllureStatusDetails(
        message: 'manual global',
        actual: 'a',
        expected: 'b',
      ),
      status: AllureStatus.failed,
    );

    final globalsFile = resultsDir.listSync().whereType<File>().singleWhere(
      (file) => file.path.endsWith('-globals.json'),
    );
    final decoded =
        jsonDecode(globalsFile.readAsStringSync()) as Map<String, dynamic>;
    final error =
        (decoded['errors'] as List<dynamic>).single as Map<String, dynamic>;
    expect(error['status'], 'failed');
    expect(error['message'], 'manual global');
    expect(error['actual'], 'a');
    expect(error['expected'], 'b');
    expect(p.basename(globalsFile.path), endsWith('-globals.json'));
  });

  test('unexpected errors resolve to broken status', () async {
    await globalError(
      error: StateError('infra boom'),
      stackTrace: StackTrace.current,
    );

    final error = await readSingleGlobalError();
    expect(error['status'], 'broken');
    expect(error['message'], contains('infra boom'));
  });

  test(
    'getMessageAndTraceFromError parses Expected/Actual from matcher text',
    () {
      final details = getMessageAndTraceFromError(
        TestFailure(
          "Expected: 'want'\n"
          "  Actual: 'got'\n"
          '   Which: is different.\n',
        ),
      );

      expect(details.message, contains("Expected: 'want'"));
      expect(details.actual, "'got'");
      expect(details.expected, "'want'");
      expect(
        getStatusFromError(TestFailure('Expected: a\n  Actual: b\n')),
        AllureStatus.failed,
      );
    },
  );

  test(
    'getMessageAndTraceFromError parses Expected/Actual after hook prefix',
    () {
      final details = getMessageAndTraceFromError(
        Exception(
          "setUp failed: Expected: 'want'\n"
          "  Actual: 'got'\n"
          '   Which: is different.\n',
        ),
      );

      expect(details.actual, "'got'");
      expect(details.expected, "'want'");
    },
  );

  test('structured actual/expected win over message parsing', () {
    final details = getMessageAndTraceFromError(
      _AssertionLikeError(
        message: "Expected: 'want'\n  Actual: 'got'\n",
        actual: 'structured-actual',
        expected: 'structured-expected',
      ),
    );

    expect(details.actual, 'structured-actual');
    expect(details.expected, 'structured-expected');
  });

  group('getGlobalErrorDetails', () {
    test(
      'infers status and preserves actual/expected from assertion error',
      () {
        final details = getGlobalErrorDetails(
          error: _AssertionLikeError(
            message: 'mismatch',
            actual: 0,
            expected: false,
          ),
          stackTrace: StackTrace.fromString('assertion stack'),
        );

        expect(details.status, AllureStatus.failed);
        expect(details.message, 'mismatch');
        expect(details.trace, 'assertion stack');
        expect(details.actual, '0');
        expect(details.expected, 'false');
      },
    );

    test('gives explicit status precedence', () {
      final error = _AssertionLikeError(
        message: 'assert mismatch',
        actual: 1,
        expected: 2,
      );

      expect(
        getGlobalErrorDetails(error: error, status: AllureStatus.broken).status,
        AllureStatus.broken,
      );
      expect(
        getGlobalErrorDetails(
          error: StateError('connection lost'),
          status: AllureStatus.failed,
        ).status,
        AllureStatus.failed,
      );
    });

    test('preserves supplied details including empty strings', () {
      const details = AllureStatusDetails(
        message: '',
        trace: '',
        actual: '',
        expected: 'value',
      );

      final normalized = getGlobalErrorDetails(details: details);
      expect(normalized.status, AllureStatus.failed);
      expect(normalized.message, '');
      expect(normalized.trace, '');
      expect(normalized.actual, '');
      expect(normalized.expected, 'value');
    });

    test('prefers trace over stack and strips ANSI formatting', () {
      final details = getGlobalErrorDetails(
        error: _TracedError(
          message: '\u001b[31mboom\u001b[0m',
          trace: '\u001b[31mcustom trace\u001b[0m',
        ),
        stackTrace: StackTrace.fromString('ignored stack'),
      );

      expect(details.status, AllureStatus.broken);
      expect(details.message, 'boom');
      expect(details.trace, 'custom trace');
    });

    test('accepts status-only calls', () {
      final failed = getGlobalErrorDetails(status: AllureStatus.failed);
      expect(failed.status, AllureStatus.failed);
      expect(failed.message, isNull);
      expect(failed.trace, isNull);

      final broken = getGlobalErrorDetails(status: AllureStatus.broken);
      expect(broken.status, AllureStatus.broken);
      expect(broken.message, isNull);
    });
  });

  group('toGlobalErrorMessage', () {
    test('prefixes the error details with the failing operation', () {
      final message = toGlobalErrorMessage(
        name: 'beforeAll hook',
        details: const AllureStatusDetails(
          message: 'connection lost',
          trace: 'stack',
        ),
        status: AllureStatus.failed,
      );

      expect(message.type, 'global_error');
      expect(message.data, <String, Object?>{
        'message': 'beforeAll hook failed: connection lost',
        'trace': 'stack',
        'status': 'failed',
      });
    });

    test('falls back to a broken status and a generic message', () {
      final message = toGlobalErrorMessage(
        name: 'setup',
        details: const AllureStatusDetails(),
        status: AllureStatus.passed,
      );

      expect(message.type, 'global_error');
      expect(message.data, <String, Object?>{
        'message': 'setup failed',
        'status': 'broken',
      });
    });
  });

  test('stripAnsi removes CSI color sequences', () {
    expect(stripAnsi('\u001b[31mred\u001b[0m'), 'red');
  });
}
