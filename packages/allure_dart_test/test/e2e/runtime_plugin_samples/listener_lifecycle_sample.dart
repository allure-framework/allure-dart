import 'package:allure_dart_test/allure_dart_test.dart';
import 'package:test/test.dart';

void main() {
  installAllure(
    lifecycle: AllureLifecycle(
      listeners: const <AllureLifecycleListener>[
        _ListenerMetadata(),
      ],
    ),
  );

  test('listener lifecycle sample', () {
    expect(2 + 2, equals(4));
  });
}

class _ListenerMetadata extends AllureLifecycleListener {
  const _ListenerMetadata();

  @override
  void beforeTestWrite(AllureTestResult result) {
    result.labels.add(const AllureLabel(name: 'listener', value: 'observed'));
  }
}
