# allure_flutter_test

`allure_flutter_test` adds Allure reporting for `flutter_test` and host-run
`integration_test` suites.

## Usage

Add the package to your `pubspec.yaml`:

```yaml
dev_dependencies:
  allure_flutter_test: ^1.0.0
```

For widget tests, replace the normal `flutter_test` import with the Allure
drop-in import:

```dart
import 'package:allure_flutter_test/flutter_test.dart';

void main() {
  testWidgets('example', (tester) async {
    expect(find.text('missing'), findsNothing);
  });
}
```

For host-run integration tests, replace the normal `integration_test` import
with the Allure integration-test wrapper:

```dart
import 'package:allure_flutter_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('example', (tester) async {
    expect(find.text('missing'), findsNothing);
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

`benchmarkWidgets` is intentionally out of scope in this phase and is only
re-exported unchanged.

This repository's CI verifies integration-test framework labeling through a
host `flutter test` smoke test that initializes
`IntegrationTestWidgetsFlutterBinding`. Running real `flutter test
integration_test/...` suites still requires a supported app/device target in the
consumer project.

## Configuration

The Flutter adapter uses the same `allure-dart.yaml` support as
`allure_dart_test`. Place the file in the package tree to set checked-in
defaults:

```yaml
resultsDir: build/allure-results
labels:
  module: app_widgets
environment:
  target: local
```

`ALLURE_RESULTS_DIR` overrides `resultsDir`, and `ALLURE_CONFIG` can point to an
explicit config file.
