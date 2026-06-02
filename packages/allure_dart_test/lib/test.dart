/// Drop-in `package:test` exports that install Allure reporting automatically.
library;

export 'package:test/test.dart'
    hide test, group, setUp, tearDown, setUpAll, tearDownAll;

export 'src/test_drop_in.dart';
