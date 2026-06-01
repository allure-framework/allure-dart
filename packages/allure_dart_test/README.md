# allure_dart_test

`allure_dart_test` is the `package:test` adapter for this workspace.

## Usage

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  allure_dart_test: ^1.0.0
```

Use the runtime plugin for existing suites:

```dart
import 'package:allure_dart_test/allure_dart_test.dart';
import 'package:test/test.dart';

void main() {
  installAllure();

  test('example', () {
    expect(2 + 2, equals(4));
  });
}
```

Or use the drop-in import:

```dart
import 'package:allure_dart_test/test.dart';

void main() {
  test('example', () {
    expect(true, isTrue);
  });
}
```

## Metadata

Runtime calls from `allure_dart_commons` are available from this package:

```dart
await testCaseName('logical checkout case');
await displayName('Checkout accepts a saved card');
await statusDetails(flaky: true);
```

For lower-level `allureTest` bodies, use the context object for durable
attachments:

```dart
allureTest('captures logs', (allure) async {
  await allure.streamAttachment(
    name: 'server log',
    type: 'text/plain',
    extension: 'log',
    content: logFile.openRead(),
  );
});
```

Runtime and in-test attachment APIs add attachments as attachment steps by
default so they keep their logical position between surrounding steps.
