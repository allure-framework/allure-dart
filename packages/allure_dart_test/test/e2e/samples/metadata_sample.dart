import 'package:allure_dart_test/allure_dart_test.dart';

void main() {
  allureTest(
    'metadata sample',
    (_) async {},
    labels: const [
      AllureLabel(name: 'framework', value: 'dart-test'),
      AllureLabel(name: 'language', value: 'dart'),
    ],
    parameters: const [
      AllureParameter(name: 'browser', value: 'chromium'),
    ],
    links: const [
      AllureLink(
        name: 'docs',
        type: 'custom',
        url: 'https://example.test/docs',
      ),
    ],
  );
}
