import 'package:allure_dart_test/allure_dart_test.dart' as allure;
import 'package:test/test.dart';

/// Installs a runtime-configured [allure.AllureLifecycle] carrying categories
/// and executor metadata, then records a run-level attachment and a
/// run-level error from inside a test body via the commons runtime facade.
void main() {
  allure.installAllure(
    lifecycle: allure.AllureLifecycle(
      categories: <allure.AllureCategory>[
        const allure.AllureCategory(
          name: 'Sample failures',
          matchedStatuses: <allure.AllureStatus>[allure.AllureStatus.failed],
        ),
      ],
      executorInfo: const allure.AllureExecutorInfo(
        name: 'e2e-executor',
        type: 'e2e',
        buildName: 'categories-executor-globals-sample-build',
      ),
    ),
  );

  test('categories executor globals sample', () async {
    await allure.globalAttachment(
      'global payload',
      'global-attachment-content',
      contentType: 'text/plain',
      fileExtension: 'txt',
    );
    await allure.globalError(message: 'global error message', known: true);
  });
}
