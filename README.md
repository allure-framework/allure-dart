# Allure Dart Integrations

> Official Allure Framework integrations for Dart and Flutter test runners.

[<img src="https://allurereport.org/public/img/allure-report.svg" height="85px" alt="Allure Report logo" align="right" />](https://allurereport.org "Allure Report")

- Learn more about Allure Report at https://allurereport.org
- 📚 [Documentation](https://allurereport.org/docs/) – discover official documentation for Allure Report
- ❓ [Questions and Support](https://github.com/orgs/allure-framework/discussions/categories/questions-support) – get help from the team and community
- 📢 [Official announcements](https://github.com/orgs/allure-framework/discussions/categories/announcements) – be in touch with the latest updates
- 💬 [General Discussion](https://github.com/orgs/allure-framework/discussions/categories/general-discussion) – engage in casual conversations, share insights and ideas with the community

---

## Overview

Allure Dart writes [Allure Report](https://allurereport.org/) result files from
Dart and Flutter tests.

Use it when you want rich test reports with statuses, steps, fixtures,
attachments, labels, links, parameters, environment information, and test plan
selection.

## Packages

| Package | Use it for |
| --- | --- |
| [`allure_dart_test`](https://pub.dev/packages/allure_dart_test) | Dart tests that use `package:test`. |
| [`allure_flutter_test`](https://pub.dev/packages/allure_flutter_test) | Flutter widget tests and host-run `integration_test` suites. |
| [`allure_dart_commons`](https://pub.dev/packages/allure_dart_commons) | Low-level Allure result writing for custom adapters and advanced integrations. |

## Requirements

- Dart SDK 3.6 or newer.
- Flutter 3.24 or newer when using `allure_flutter_test`.
- The Allure command-line tool when you want to turn `allure-results` into an
  HTML report.

## Dart Tests

Add the adapter:

```bash
dart pub add --dev allure_dart_test
```

For a new or easy-to-change suite, replace the `package:test` import with the
drop-in Allure import:

```dart
import 'package:allure_dart_test/test.dart';
import 'package:allure_dart_test/allure_dart_test.dart' as allure;

void main() {
  group('profile api', () {
    test('returns current user @allure.label.feature:profile', () async {
      await allure.owner('team-qa');
      await allure.parameter('userId', 42);

      await allure.step('request profile', (step) async {
        await step.parameter('endpoint', '/me');
        await allure.attachment(
          'response',
          '{"name":"Ada"}',
          contentType: 'application/json',
          fileExtension: 'json',
        );
      });

      expect(2 + 2, equals(4));
    });
  });
}
```

For an existing suite where you want to keep importing `package:test`, install
the runtime plugin once:

```dart
import 'package:allure_dart_test/allure_dart_test.dart';
import 'package:test/test.dart';

void main() {
  installAllure();

  test('example', () async {
    await step('calculate answer', (_) async {
      expect(40 + 2, equals(42));
    });
  });
}
```

Run your tests as usual:

```bash
dart test
```

By default, result files are written to `allure-results`.

## Flutter Tests

Add the Flutter adapter:

```bash
flutter pub add --dev allure_flutter_test
```

For widget tests, replace the normal `flutter_test` import with the Allure
drop-in import:

```dart
import 'package:allure_flutter_test/flutter_test.dart';
import 'package:allure_flutter_test/allure_flutter_test.dart' as allure;

void main() {
  testWidgets('renders empty state', (tester) async {
    await allure.feature('home');
    await allure.step('pump widget', (_) async {
      await tester.pumpWidget(const MyApp());
    });

    expect(find.text('No items'), findsOneWidget);
  });
}
```

If you need to keep the original framework imports or provide a custom
`AllureLifecycle`, install the runtime explicitly in `test/flutter_test_config.dart`:

```dart
import 'dart:async';

import 'package:allure_flutter_test/allure_flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  installAllure();
  await testMain();
}
```

Run widget tests as usual:

```bash
flutter test
```

For host-run integration tests, use the integration-test wrapper:

```dart
import 'package:allure_flutter_test/integration_test.dart';
import 'package:allure_flutter_test/allure_flutter_test.dart' as allure;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signs in', (tester) async {
    await allure.story('sign in');
    expect(find.text('Sign in'), findsOneWidget);
  });
}
```

## Generate a Report

After a test run, generate or serve the Allure report from the result directory:

```bash
allure generate allure-results --clean -o allure-report
allure open allure-report
```

Or open it directly:

```bash
allure serve allure-results
```

To use another result directory, set `ALLURE_RESULTS_DIR` before running tests:

```bash
ALLURE_RESULTS_DIR=build/allure-results dart test
ALLURE_RESULTS_DIR=build/allure-results flutter test
```

## Add Metadata

The adapters expose runtime helpers you can call inside tests and fixtures:

```dart
await allure.displayName('Readable test name');
await allure.description('Checks the successful profile path.');
await allure.testCaseName('profile current user success path');
await allure.allureId('AUTH-42');
await allure.owner('team-qa');
await allure.severity('critical');
await allure.epic('Mobile app');
await allure.feature('Authentication');
await allure.story('Sign in');
await allure.tag('smoke');
await allure.issue('https://example.com/issues/AUTH-42', name: 'AUTH-42');
await allure.tms('https://example.com/cases/C123', name: 'C123');
await allure.parameter('browser', 'chromium');
await allure.statusDetails(flaky: true);
await allure.attachmentPath(
  'screenshot',
  'screenshots/failure.png',
  contentType: 'image/png',
);
```

Runtime and in-test attachment APIs add attachments as attachment steps by
default so they stay in the same logical order as surrounding steps. Lower-level
`AllureLifecycle` APIs still expose explicit placement control for framework
adapter integrations.

You can also add static metadata in test names or tags:

```dart
test(
  'checkout works @allure.id:123 @allure.label.owner:payments',
  () async {
    // ...
  },
);
```

Supported inline markers include:

- `@allure.id:123`
- `@allure.label.owner:team-qa`
- `@allure.link.issue:https://example.com/ISSUE-1`
- `@allure.name:Readable test name`

## Test Plans

When `ALLURE_TESTPLAN_PATH` points to an Allure test plan JSON file, the
drop-in `test`, `group`, and `testWidgets` wrappers skip tests that are not in
the plan. Suites that use `installAllure()` with the original framework imports
still run the test and mark it with the `ALLURE_TESTPLAN_SKIP` label.

```bash
ALLURE_TESTPLAN_PATH=testplan.json dart test
```

Entries can match by Allure ID or by the test selector produced by the adapter.

## Advanced Runtime And Lifecycle APIs

`allure_dart_commons` exposes low-level APIs for custom adapters and advanced
test helpers:

- `AllureLifecycleListener` observes lifecycle events and can mutate a result
  before it is written.
- `AllureExecutorInfo` writes `executor.json` with CI or launcher metadata.
- `AllureStatusDetails` supports `known`, `muted`, and `flaky`
  classification flags in addition to messages, traces, actual, and expected.
- Prepared and stream attachment APIs let producers write large or late
  artifacts before the result references them.

Example:

```dart
final lifecycle = AllureLifecycle(
  executorInfo: const AllureExecutorInfo(
    name: 'GitHub Actions',
    type: 'github',
    buildName: 'Build #42',
  ),
  listeners: const [MyAllureListener()],
);

await lifecycle.addAttachmentStreamToRoot(
  testUuid,
  name: 'server log',
  contentType: 'text/plain',
  fileExtension: 'log',
  content: logFile.openRead(),
);
```
