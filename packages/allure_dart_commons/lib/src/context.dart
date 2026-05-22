import 'dart:async';

import 'runtime.dart';

const Symbol _allureRootUuidKey = #allure.rootUuid;
const Symbol _allureTestUuidKey = #allure.testUuid;

AllureExecutionContext? getZoneExecutionContext() {
  final rootUuid = Zone.current[_allureRootUuidKey] as String?;
  if (rootUuid == null) {
    return null;
  }
  final testUuid = Zone.current[_allureTestUuidKey] as String? ?? rootUuid;
  return AllureExecutionContext(rootUuid: rootUuid, testUuid: testUuid);
}

T runWithAllureContext<T>({
  required String rootUuid,
  required String testUuid,
  required T Function() body,
}) {
  return runZoned(
    body,
    zoneValues: <Object?, Object?>{
      _allureRootUuidKey: rootUuid,
      _allureTestUuidKey: testUuid,
    },
  );
}
