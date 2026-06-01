# allure_flutter_test

`allure_flutter_test` adds Allure reporting for `flutter_test` and host-run
`integration_test` suites.

## Usage

Add the package to your `pubspec.yaml`:

```yaml
dev_dependencies:
  allure_flutter_test: ^1.0.0
```

Install once for existing `flutter_test` suites with `flutter_test_config.dart`:

```dart
import 'dart:async';

import 'package:allure_flutter_test/allure_flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  installAllure();
  await testMain();
}
```

Or use the drop-in wrapper:

```dart
import 'package:allure_flutter_test/flutter_test.dart';

void main() {
  testWidgets('example', (tester) async {
    expect(find.text('missing'), findsNothing);
  });
}
```

For host-run integration tests:

```dart
import 'package:allure_flutter_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('example', (tester) async {
    expect(find.text('missing'), findsNothing);
  });
}
```

`benchmarkWidgets` is intentionally out of scope in this phase and is only
re-exported unchanged.

This repository's CI verifies integration-test framework labeling through a
host `flutter test` smoke test that initializes
`IntegrationTestWidgetsFlutterBinding`. Running real `flutter test
integration_test/...` suites still requires a supported app/device target in the
consumer project.
