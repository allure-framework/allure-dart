/// Allure adapter APIs for `package:test` suites.
library;

export 'package:allure_dart_commons/allure_dart_commons.dart'
    hide allureTestPlanSkipLabel;

export 'src/runtime_plugin.dart';
export 'src/test_api.dart';

/// Label name used to mark tests excluded by an Allure test plan.
const String allureTestPlanSkipLabel = 'ALLURE_TESTPLAN_SKIP';
