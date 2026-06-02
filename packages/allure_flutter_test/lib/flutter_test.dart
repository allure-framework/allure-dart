/// Drop-in `flutter_test` exports that install Allure reporting automatically.
///
/// {@canonicalFor flutter_test_drop_in.test}
/// {@canonicalFor flutter_test_drop_in.group}
/// {@canonicalFor flutter_test_drop_in.setUp}
/// {@canonicalFor flutter_test_drop_in.tearDown}
/// {@canonicalFor flutter_test_drop_in.setUpAll}
/// {@canonicalFor flutter_test_drop_in.tearDownAll}
/// {@canonicalFor flutter_test_drop_in.testWidgets}
library;

export 'package:flutter_test/flutter_test.dart'
    hide test, group, setUp, tearDown, setUpAll, tearDownAll, testWidgets;

export 'allure_flutter_test.dart';
export 'src/flutter_test_drop_in.dart'
    show test, group, setUp, tearDown, setUpAll, tearDownAll, testWidgets;
