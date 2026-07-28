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

### Auto screenshot-on-failure and golden-diff attachments (opt-in)

`installAllure` accepts two opt-in flags, each installing a process-wide hook
the first time it is passed as `true`:

```dart
installAllure(
  autoScreenshotOnFailure: true,
  autoAttachGoldenDiff: true,
);
```

- `autoScreenshotOnFailure` wraps `flutter_test`'s `reportTestException` to
  detect a failing test, then captures a screenshot of the current widget
  tree in a `tearDown` and attaches it as `screenshot-on-failure` (PNG).
- `autoAttachGoldenDiff` wraps `goldenFileComparator` so that any
  `matchesGoldenFile` mismatch attaches the actual rendered PNG as
  `golden-actual`, plus (best-effort, when the comparator is the default
  `LocalFileComparator`) the `failures/*.png` master/test/diff images it
  already writes to disk.

Both hooks are best-effort: a capture or attachment failure is swallowed so
it never masks the original test failure. Both are monotonic — once enabled
by any `installAllure(...)` call in the process, a later bare
`installAllure()` call (with the flags left at their `false` default) does
not disable them. Enable them once, for example in
`test/flutter_test_config.dart`:

```dart
import 'dart:async';

import 'package:allure_flutter_test/allure_flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  installAllure(autoScreenshotOnFailure: true, autoAttachGoldenDiff: true);
  await testMain();
}
```

Users can still attach screenshots or golden files manually with the Allure
attachment APIs (for example the top-level `attachment(...)` function) from
within their test body or a `tearDown` callback, whether or not these hooks
are enabled.

## Skip Semantics

Declaration-time `skip: true` on the drop-in wrappers is converted to a runtime
`markTestSkipped` so Allure still writes a skipped result.

### Plain `installAllure()` with original `flutter_test` imports

The Allure runtime plugin (shared with `allure_dart_test`) schedules a result
from a global `setUp` hook. `flutter_test` is built on `package:test`, so its
own declaration-time skip never runs `setUp` for a skipped test — with plain
`installAllure()` plus the original imports, a declared `skip: true` produces
**no Allure result at all**, not even a skipped one. Prefer a runtime
self-skip instead:

```dart
// Before: no Allure result is produced for this test.
import 'package:allure_flutter_test/allure_flutter_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  installAllure();

  testWidgets('renders empty state', (tester) async {
    // ...
  }, skip: true);
}
```

```dart
// After: markTestSkipped still lets setUp/tearDown run and writes a
// skipped Allure result.
import 'package:allure_flutter_test/allure_flutter_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  installAllure();

  testWidgets('renders empty state', (tester) async {
    markTestSkipped('temporarily disabled');
  });
}
```

Or switch the file to the drop-in import
(`package:allure_flutter_test/flutter_test.dart`) — its `test`/`testWidgets`/
`group` wrappers already convert a declared `skip` into a runtime self-skip
for you.

### Group-skip tradeoff on the drop-in wrappers

Same tradeoff as `allure_dart_test`: the drop-in `group`'s declaration-time
`skip` is tracked on an internal registry only and is **not** forwarded to
the underlying framework group skip. Nested tests still run and each
self-skips at runtime via `markTestSkipped`, so `setUp`/`setUpAll`/
`tearDown` inside a drop-in skipped group **may still run**, unlike a stock
declaration group skip. Skip individual tests instead if fixtures must not
run at all.

### `testWidgets` variants

Each value of a `variant` produces its own `flutter_test` run and its own
Allure result, named `<description> (variant: <value>)` with a `variant`
parameter carrying the value. That naming intentionally matches
`flutter_test`'s own internal variant-naming format so the declared Allure
metadata lines up with the runtime `LiveTest` name — this is a deliberate
coupling to the `flutter_test` SDK's naming convention, not an
implementation detail that is free to drift:

```dart
testWidgets(
  'wraps testWidgets variants',
  (tester) async {
    // ...
  },
  variant: ValueVariant<String>(<String>{'compact', 'expanded'}),
);
```

The above declares one `flutter_test` case but produces two Allure results:
`wraps testWidgets variants (variant: compact)` and `wraps testWidgets
variants (variant: expanded)`, each carrying a `variant` parameter with its
respective value.

`testWidgets` runs its body on a fake async zone, so real I/O Allure
attachment APIs (`attachment`, `attachmentPath`, or anything that reads a
stream) must run inside `tester.runAsync(...)`; otherwise the fake zone never
pumps the real I/O callbacks and the test hangs. See
`test/samples/attachment_widget_sample.dart` for the pattern.

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
