# allure_dart_commons

`allure_dart_commons` contains the framework-agnostic Allure model, lifecycle,
runtime message, and writer primitives shared by the Dart test adapters in this
workspace.

Use this package when you need low-level Allure result generation without the
`package:test` or Flutter adapter layers.

## Advanced APIs

- `AllureLifecycleListener` can observe lifecycle events and mutate a
  `TestResult` before it is written.
- `AllureExecutorInfo` writes `executor.json` sidecar metadata.
- `AllureStatusDetails` preserves `known`, `muted`, and `flaky`
  classifications.
- `addAttachmentStreamToRoot` and `addPreparedAttachmentToRoot` write large or
  late artifacts before the result references them.

All result and attachment writes use a temporary file followed by rename so
downstream report generation does not see partially written payloads.
