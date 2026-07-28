import 'package:allure_dart_commons/allure_dart_commons.dart';

import 'package_test_registry.dart';
import 'package_test_support.dart';

/// Shared skip / test-plan resolution for `package:test`-style drop-ins.
class PreparedPackageTestDeclaration {
  /// Creates a prepared declaration.
  const PreparedPackageTestDeclaration({
    required this.metadata,
    required this.excludedByTestPlan,
    required this.shouldRuntimeSkip,
    required this.runtimeSkipReason,
  });

  /// Declared Allure metadata registered for this test.
  final PackageTestMetadata metadata;

  /// Whether the test is excluded by the active Allure test plan.
  final bool excludedByTestPlan;

  /// Whether the body should self-skip via `markTestSkipped` at runtime.
  final bool shouldRuntimeSkip;

  /// Reason passed to `markTestSkipped` when [shouldRuntimeSkip] is true.
  final String runtimeSkipReason;

  /// Declaration-time skip value for APIs that accept `Object? skip`.
  ///
  /// Test-plan exclusion stays a declaration skip so `package:test` produces
  /// no Allure result. User skips are *not* returned here — those must run
  /// through the normal path and self-skip so Allure fixtures still fire.
  Object? get declarationSkip =>
      excludedByTestPlan ? 'Excluded by Allure test plan' : null;

  /// Declaration-time skip flag for APIs that accept `bool? skip`.
  bool? get declarationSkipFlag => excludedByTestPlan ? true : null;
}

/// Registers metadata and resolves skip / test-plan handling for one test.
///
/// Callers must ensure the Allure runtime plugin is installed first.
/// When [packagePath] is already known (e.g. shared across test variants),
/// pass it to skip another stack-based path resolution.
PreparedPackageTestDeclaration preparePackageTestDeclaration({
  required Object? description,
  required Object? skip,
  Object? tags,
  Uri? locationUri,
  StackTrace? stackTrace,
  List<String> ignoredLibrarySuffixes = const <String>[],
  String? packagePath,
  String? rawName,
  String? testCaseName,
  Iterable<AllureParameter> additionalParameters = const <AllureParameter>[],
}) {
  final registry = PackageTestScopeRegistry.instance;
  final resolvedPackagePath =
      packagePath ??
      resolvePackageTestPathFromDeclaration(
        locationUri: locationUri,
        stackTrace: stackTrace,
        ignoredLibrarySuffixes: ignoredLibrarySuffixes,
      );
  final groupPath = registry.currentPath;
  final userSkipped = skip != null && skip != false;
  final isSkipped = userSkipped || registry.isCurrentPathSkipped;
  final declaredMetadata = buildPackageTestMetadata(
    rawName: rawName ?? description?.toString() ?? '',
    rawTags: normalizePackageTestTags(tags),
    groupPath: groupPath,
    packagePath: resolvedPackagePath,
    skipped: isSkipped,
    testCaseName: testCaseName,
    additionalParameters: additionalParameters,
  );
  registry.registerMetadata(declaredMetadata);

  final testPlan = parseTestPlan();
  final excludedByTestPlan =
      testPlan != null &&
      !includedInTestPlan(
        testPlan,
        id: declaredMetadata.externalId,
        fullName: declaredMetadata.fullName,
        nativeSelector: declaredMetadata.nativeSelector,
        tags: declaredMetadata.rawTags,
      );
  // Plan-excluded declarations never become lifecycle children, so omit them
  // from expected child counts used to flush group fixtures.
  if (!excludedByTestPlan) {
    registry.registerTest(packagePath: resolvedPackagePath);
  }

  return PreparedPackageTestDeclaration(
    metadata: declaredMetadata,
    excludedByTestPlan: excludedByTestPlan,
    shouldRuntimeSkip: isSkipped && !excludedByTestPlan,
    runtimeSkipReason: skip is String ? skip : 'Skipped',
  );
}

/// Pushes a group onto the declaration registry and returns its package path.
///
/// Callers must ensure the Allure runtime plugin is installed first. The
/// declaration-time `skip` is tracked on the registry only — it is not
/// forwarded to the framework `group` call, so nested tests still run and can
/// self-skip while keeping setUp/tearDown intact.
String? pushDeclaredPackageTestGroup({
  required Object? description,
  required Object? skip,
  Uri? locationUri,
  StackTrace? stackTrace,
  List<String> ignoredLibrarySuffixes = const <String>[],
}) {
  final packagePath = resolvePackageTestPathFromDeclaration(
    locationUri: locationUri,
    stackTrace: stackTrace,
    ignoredLibrarySuffixes: ignoredLibrarySuffixes,
  );
  PackageTestScopeRegistry.instance.pushGroup(
    description?.toString() ?? '',
    packagePath: packagePath,
    skipped: skip != null && skip != false,
  );
  return packagePath;
}
