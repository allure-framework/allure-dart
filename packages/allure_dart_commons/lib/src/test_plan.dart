import 'dart:convert';

import 'model.dart';
import 'platform.dart';
import 'test_plan_loader.dart';
import 'utils.dart';

/// Single entry in an Allure test plan.
class TestPlanEntry {
  /// Creates a test plan entry.
  const TestPlanEntry({this.id, this.selector});

  /// Optional Allure id to match.
  final Object? id;

  /// Optional full-name or native selector to match.
  final String? selector;
}

/// Parsed Allure test plan version 1.
class TestPlanV1 {
  /// Creates a test plan.
  const TestPlanV1({required this.tests});

  /// Entries included in the test plan.
  final List<TestPlanEntry> tests;
}

// Cache keyed by the resolved `ALLURE_TESTPLAN_PATH` value (or a sentinel
// when unset/empty). Only populated for the platform environment lookup
// path, since that value is immutable for the lifetime of the process.
const _noTestPlanPathSentinel = '\u0000';
final _testPlanCache = <String, TestPlanV1?>{};

/// Parses an Allure test plan from `ALLURE_TESTPLAN_PATH`.
///
/// When [environment] is omitted, the result is cached per process for the
/// resolved path, since drop-ins may call this once per test declaration.
/// Passing an explicit [environment] always parses fresh and never reads or
/// writes that cache.
TestPlanV1? parseTestPlan([Map<String, String>? environment]) {
  final usesProcessEnvironment = environment == null;
  final source = environment ?? allureEnvironment;
  final path = source['ALLURE_TESTPLAN_PATH'];

  if (usesProcessEnvironment) {
    final cacheKey =
        (path == null || path.isEmpty) ? _noTestPlanPathSentinel : path;
    if (_testPlanCache.containsKey(cacheKey)) {
      return _testPlanCache[cacheKey];
    }
    final parsed = _parseTestPlanFromPath(path);
    _testPlanCache[cacheKey] = parsed;
    return parsed;
  }

  return _parseTestPlanFromPath(path);
}

TestPlanV1? _parseTestPlanFromPath(String? path) {
  if (path == null || path.isEmpty) {
    return null;
  }

  final contents = loadTestPlanContents(path);
  if (contents == null) {
    return null;
  }

  try {
    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, dynamic>) {
      allureLogWarning('Allure: test plan root must be a JSON object: $path');
      return null;
    }
    final version = decoded['version'];
    if (version == null || version.toString() != '1.0') {
      allureLogWarning(
        'Allure: unsupported or missing test plan version: $version',
      );
      return null;
    }
    final tests = decoded['tests'];
    if (tests is! List) {
      allureLogWarning('Allure: test plan does not contain a tests array');
      return null;
    }
    final entries = tests
        .whereType<Map>()
        .where((entry) {
          final hasId = entry['id'] != null;
          final hasSelector = entry['selector'] != null &&
              entry['selector'].toString().isNotEmpty;
          if (!hasId && !hasSelector) {
            allureLogWarning('Allure: ignoring malformed test plan entry');
          }
          return hasId || hasSelector;
        })
        .map(
          (entry) => TestPlanEntry(
            id: entry['id'],
            selector: entry['selector']?.toString(),
          ),
        )
        .toList();
    // A valid empty `tests` array means "select nothing". Only treat the plan
    // as unavailable when every declared entry was malformed.
    if (tests.isNotEmpty && entries.isEmpty) {
      return null;
    }
    return TestPlanV1(tests: entries);
  } catch (error) {
    allureLogWarning('Allure: unable to parse test plan: $error');
    return null;
  }
}

/// Whether a test identified by id, selector, or tags is included in [plan].
bool includedInTestPlan(
  TestPlanV1 plan, {
  String? id,
  String? fullName,
  String? nativeSelector,
  Iterable<String>? tags,
}) {
  final effectiveId = id ?? _extractAllureIdFromTags(tags);

  for (final entry in plan.tests) {
    final idMatched = effectiveId != null &&
        entry.id != null &&
        entry.id.toString() == effectiveId;
    final selectorMatched = fullName != null &&
        entry.selector != null &&
        entry.selector == fullName;
    final nativeSelectorMatched = nativeSelector != null &&
        entry.selector != null &&
        entry.selector == nativeSelector;
    if (idMatched || selectorMatched || nativeSelectorMatched) {
      return true;
    }
  }
  return false;
}

/// Extracts an Allure id from tag expressions.
String? extractAllureIdFromTags(Iterable<String>? tags) {
  return _extractAllureIdFromTags(tags);
}

/// Adds the Allure test-plan skip marker to [labels].
void addSkipLabel(List<AllureLabel> labels) {
  labels.add(const AllureLabel(name: allureTestPlanSkipLabel, value: 'true'));
}

String? _extractAllureIdFromTags(Iterable<String>? tags) {
  if (tags == null) {
    return null;
  }
  final expressions = <RegExp>[
    RegExp(r'^@allure\.id=(.+)$'),
    RegExp(r'^@allure\.id:(.+)$'),
  ];
  for (final tag in tags) {
    for (final expression in expressions) {
      final match = expression.firstMatch(tag);
      if (match != null) {
        return match.group(1);
      }
    }
  }
  return null;
}
