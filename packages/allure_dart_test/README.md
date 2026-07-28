# allure_dart_test

[![pub package](https://img.shields.io/pub/v/allure_dart_test.svg)](https://pub.dev/packages/allure_dart_test)

`allure_dart_test` is the `package:test` adapter for this workspace.

## Usage

Add the package to your `pubspec.yaml`:

```yaml
dev_dependencies:
  allure_dart_test: ^1.1.0
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

## Skip Semantics

Declaration-time `skip: true` (and group-level skip) on the drop-in wrappers is
converted to a runtime `markTestSkipped` so Allure still writes a skipped
result.

### Plain `installAllure()` with original `package:test` imports

The Allure runtime plugin schedules a result from a global `setUp` hook.
`package:test`'s own declaration-time skip never runs `setUp` for a skipped
test, so with plain `installAllure()` plus the original imports, a declared
`skip: true` produces **no Allure result at all** — not even a skipped one:

```dart
// Before: no Allure result is produced for this test.
import 'package:allure_dart_test/allure_dart_test.dart';
import 'package:test/test.dart';

void main() {
  installAllure();

  test('checkout applies a discount', () {
    // ...
  }, skip: true);
}
```

Prefer a runtime self-skip so Allure still writes a skipped result:

```dart
// After: markTestSkipped still lets setUp/tearDown run and writes a
// skipped Allure result.
import 'package:allure_dart_test/allure_dart_test.dart';
import 'package:test/test.dart';

void main() {
  installAllure();

  test('checkout applies a discount', () {
    markTestSkipped('temporarily disabled');
  });
}
```

Or switch the file to the drop-in import
(`package:allure_dart_test/test.dart`) — its `test`/`group` wrappers already
convert a declared `skip` into a runtime self-skip for you, so plain
`skip: true` keeps working and still writes a skipped result.

### Group-skip tradeoff on the drop-in wrappers

The drop-in `group`'s declaration-time `skip` is tracked on an internal
registry only — it is **not** forwarded to `package:test`'s own group
`skip:`. Nested tests still run through `package:test`'s normal scheduling
and each self-skips at runtime once it sees a skipped ancestor group; that
self-skip is what lets Allure write a skipped result per nested test.

The tradeoff: unlike a stock `package:test` declaration group skip (which
never runs the group's fixtures at all), `setUp`/`setUpAll`/`tearDown` inside
a drop-in skipped group **may still run**, because each nested test still
executes far enough to reach and call `markTestSkipped` itself:

```dart
import 'package:allure_dart_test/test.dart';

void main() {
  group('checkout flow', () {
    setUp(() {
      // Still runs once per nested test, even though the group is skipped.
    });

    test('applies a discount', () {
      // Never reached — this body is replaced by a runtime self-skip.
    });
  }, skip: true);
}
```

If fixtures must not run at all when a suite is skipped, skip each `test(...,
skip: true)` individually instead of skipping the group, or guard the
fixture body itself.

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

## Configuration

The adapter loads `allure-dart.yaml` or `allure-dart.yml` from the current
package tree. Use it for checked-in local defaults such as module labels:

```yaml
resultsDir: build/allure-results
labels:
  module: checkout
  layer:
    - api
environment:
  target: local
```

`ALLURE_RESULTS_DIR` overrides `resultsDir`, and `ALLURE_CONFIG` can point to an
explicit config file.
