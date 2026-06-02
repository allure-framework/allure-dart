import 'package:allure_dart_commons/allure_dart_commons.dart';
import 'package:allure_dart_test/allure_dart_test.dart'
    show AllureTestRuntimePlugin;
import 'package:flutter/widgets.dart';
import 'package:integration_test/integration_test.dart';

/// Installs the Allure runtime plugin for Flutter tests.
void installAllure({AllureLifecycle? lifecycle}) {
  AllureTestRuntimePlugin.ensureInstalled(
    lifecycle: lifecycle,
    frameworkLabelResolver: _resolveFrameworkLabel,
  );
}

String _resolveFrameworkLabel() {
  final binding = WidgetsBinding.instance;
  if (binding is IntegrationTestWidgetsFlutterBinding) {
    return 'flutter-integration-test';
  }
  return 'flutter-test';
}
