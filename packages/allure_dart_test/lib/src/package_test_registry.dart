import 'package_test_support.dart';

/// Registry of declared `package:test` scopes and metadata.
class PackageTestScopeRegistry {
  PackageTestScopeRegistry._();

  /// Singleton registry used by the drop-in test wrappers.
  static final PackageTestScopeRegistry instance = PackageTestScopeRegistry._();

  final List<_DeclaredGroup> _declarationStack = <_DeclaredGroup>[];
  final Map<String, _DeclaredScope> _scopes = <String, _DeclaredScope>{};
  final Map<String, PackageTestMetadata> _metadataByFullName =
      <String, PackageTestMetadata>{};

  /// Current declaration-time group path.
  List<String> get currentPath => List<String>.unmodifiable(
        _declarationStack.map((group) => group.name),
      );

  /// Current package-relative test file path, when known.
  String? get currentPackagePath =>
      _declarationStack.isEmpty ? null : _declarationStack.last.packagePath;

  /// Pushes a group onto the declaration stack.
  void pushGroup(String name, {required String? packagePath}) {
    final resolvedPackagePath = packagePath ?? currentPackagePath;
    _declarationStack.add(
      _DeclaredGroup(name: name, packagePath: resolvedPackagePath),
    );
    _scopeForPath(
      currentPath,
      packagePath: resolvedPackagePath,
    );
  }

  /// Pops the latest group from the declaration stack.
  void popGroup() {
    if (_declarationStack.isNotEmpty) {
      _declarationStack.removeLast();
    }
  }

  /// Registers a declared test for scope child counts.
  void registerTest({required String? packagePath}) {
    final resolvedPackagePath = packagePath ?? currentPackagePath;
    _scopeForPath(
      const <String>[],
      packagePath: resolvedPackagePath,
    ).expectedChildrenCount++;
    for (var index = 0; index < _declarationStack.length; index++) {
      final path = currentPath.take(index + 1).toList();
      _scopeForPath(path, packagePath: resolvedPackagePath)
          .expectedChildrenCount++;
    }
  }

  /// Stores declaration-time metadata for a test.
  void registerMetadata(PackageTestMetadata metadata) {
    _metadataByFullName[metadata.fullName] = metadata;
  }

  /// Returns declaration-time metadata for [fullName], when present.
  PackageTestMetadata? metadataForFullName(String fullName) {
    return _metadataByFullName[fullName];
  }

  /// Returns the scope id for a group [path].
  String scopeIdForPath(
    List<String> path, {
    required String? packagePath,
  }) {
    return buildPackageTestScopeId(packagePath, path);
  }

  /// Returns the expected child count for a group [path].
  int? expectedChildrenForPath(
    List<String> path, {
    required String? packagePath,
  }) {
    return _scopes[scopeIdForPath(path, packagePath: packagePath)]
        ?.expectedChildrenCount;
  }

  _DeclaredScope _scopeForPath(
    List<String> path, {
    required String? packagePath,
  }) {
    final id = scopeIdForPath(path, packagePath: packagePath);
    return _scopes.putIfAbsent(
      id,
      () => _DeclaredScope(id: id, name: path.isEmpty ? null : path.last),
    );
  }
}

class _DeclaredGroup {
  _DeclaredGroup({
    required this.name,
    required this.packagePath,
  });

  final String name;
  final String? packagePath;
}

class _DeclaredScope {
  _DeclaredScope({
    required this.id,
    required this.name,
  });

  final String id;
  final String? name;
  int expectedChildrenCount = 0;
}
