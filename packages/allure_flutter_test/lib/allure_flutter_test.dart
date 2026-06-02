/// Allure adapter APIs for Flutter widget and integration tests.
library;

export 'package:allure_dart_commons/allure_dart_commons.dart'
    hide allureTestPlanSkipLabel;

export 'src/flutter_install.dart';

/// Label name used to mark tests excluded by an Allure test plan.
const String allureTestPlanSkipLabel = 'ALLURE_TESTPLAN_SKIP';
