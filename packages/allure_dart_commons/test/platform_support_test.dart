import 'package:allure_dart_commons/allure_dart_commons.dart';
import 'package:test/test.dart';

void main() {
  test(
    'platform helpers load and explain unsupported filesystem writes',
    () async {
      expect(() {
        final environment = allureEnvironment;
        getHostLabel(environment);
        getThreadLabel(null, environment);
      }, returnsNormally);

      if (!allureSupportsFilesystem) {
        await expectLater(
          AllureResultsWriter().ensureInitialized(),
          throwsA(
            isA<UnsupportedError>()
                .having((error) => error.message, 'message', contains('Allure'))
                .having(
                  (error) => error.message,
                  'message',
                  contains('filesystem'),
                ),
          ),
        );
      }
    },
  );
}
