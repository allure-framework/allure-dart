import 'dart:convert';

/// Status values written to Allure result files.
enum AllureStatus {
  /// The test reached an assertion-style failure.
  failed,

  /// The test stopped because of an unexpected error.
  broken,

  /// The test completed successfully.
  passed,

  /// The test was skipped or excluded before execution.
  skipped;

  /// Serialized Allure status value.
  String get value => name;
}

/// Execution stage values written to Allure result files.
enum AllureStage {
  /// The test or fixture is known but has not started yet.
  scheduled,

  /// The test, fixture, or step is currently running.
  running,

  /// The test, fixture, or step has completed.
  finished,

  /// The test is pending, commonly because it was skipped.
  pending,

  /// The test, fixture, or step was interrupted before normal completion.
  interrupted;

  /// Serialized Allure stage value.
  String get value => name;
}

/// Visibility mode for an Allure parameter.
enum AllureParameterMode {
  /// The parameter is shown normally in the report.
  defaultMode('default'),

  /// The parameter is shown with its value masked.
  masked('masked'),

  /// The parameter is hidden from the rendered report.
  hidden('hidden');

  /// Creates a parameter mode with its serialized [value].
  const AllureParameterMode(this.value);

  /// Serialized Allure parameter mode value.
  final String value;
}

/// Name/value metadata label attached to an Allure result.
class AllureLabel {
  /// Creates an Allure label.
  const AllureLabel({required this.name, required this.value});

  /// Label name, such as `suite`, `feature`, or `tag`.
  final String name;

  /// Label value.
  final String value;

  /// Converts this label to the Allure JSON representation.
  Map<String, String> toJson() =>
      <String, String>{'name': name, 'value': value};
}

/// Link metadata attached to an Allure result.
class AllureLink {
  /// Creates an Allure link.
  const AllureLink({
    required this.url,
    this.name,
    this.type,
  });

  /// Link URL or template value.
  final String url;

  /// Optional display name for the link.
  final String? name;

  /// Optional link type, such as `issue` or `tms`.
  final String? type;

  /// Converts this link to the Allure JSON representation.
  Map<String, String> toJson() {
    return _compactMap<String>({
      'url': url,
      'name': name,
      'type': type,
    });
  }
}

/// Runtime parameter attached to a result, fixture, or step.
class AllureParameter {
  /// Creates an Allure parameter.
  const AllureParameter({
    required this.name,
    required this.value,
    this.excluded,
    this.mode,
  });

  /// Parameter name.
  final String name;

  /// Serialized parameter value.
  final String value;

  /// Whether the parameter is excluded from history id calculation.
  final bool? excluded;

  /// Optional display mode for the parameter.
  final AllureParameterMode? mode;

  /// Converts this parameter to the Allure JSON representation.
  Map<String, Object?> toJson() {
    return _compactMap<Object?>({
      'name': name,
      'value': value,
      'excluded': excluded,
      'mode': mode?.value,
    });
  }
}

/// Attachment metadata recorded in an Allure result.
class AllureAttachment {
  /// Creates attachment metadata.
  const AllureAttachment({
    required this.name,
    required this.source,
    this.type,
    this.size,
  });

  /// Display name of the attachment.
  final String name;

  /// File name of the attachment inside the results directory.
  final String source;

  /// MIME type of the attachment, when known.
  final String? type;

  /// Attachment size in bytes, when known.
  final int? size;

  /// Converts this attachment to the Allure JSON representation.
  Map<String, Object?> toJson() {
    return _compactMap<Object?>({
      'name': name,
      'source': source,
      'type': type,
      'size': size,
    });
  }
}

/// Additional status details for a result, fixture, step, or global error.
class AllureStatusDetails {
  /// Creates status details.
  const AllureStatusDetails({
    this.message,
    this.trace,
    this.known,
    this.muted,
    this.flaky,
    this.actual,
    this.expected,
  });

  /// Human-readable failure or skip message.
  final String? message;

  /// Stack trace or diagnostic trace text.
  final String? trace;

  /// Whether the issue is marked as known.
  final bool? known;

  /// Whether the issue is muted in reporting.
  final bool? muted;

  /// Whether the issue is marked as flaky.
  final bool? flaky;

  /// Actual value captured from assertion-style failures.
  final String? actual;

  /// Expected value captured from assertion-style failures.
  final String? expected;

  /// Whether no status detail fields are set.
  bool get isEmpty =>
      message == null &&
      trace == null &&
      known == null &&
      muted == null &&
      flaky == null &&
      actual == null &&
      expected == null;

  /// Returns a copy where non-null values from [other] override this instance.
  AllureStatusDetails merge(AllureStatusDetails other) {
    return AllureStatusDetails(
      message: other.message ?? message,
      trace: other.trace ?? trace,
      known: other.known ?? known,
      muted: other.muted ?? muted,
      flaky: other.flaky ?? flaky,
      actual: other.actual ?? actual,
      expected: other.expected ?? expected,
    );
  }

  /// Converts these details to the Allure JSON representation.
  Map<String, Object?> toJson() {
    return _compactMap<Object?>({
      'message': message,
      'trace': trace,
      'known': known,
      'muted': muted,
      'flaky': flaky,
      'actual': actual,
      'expected': expected,
    });
  }
}

/// Shared executable fields for Allure tests, fixtures, and steps.
abstract class AllureExecutable {
  /// Creates an executable result object.
  AllureExecutable({
    this.name,
    this.status,
    this.statusDetails = const AllureStatusDetails(),
    this.stage = AllureStage.pending,
    this.description,
    this.descriptionHtml,
    List<AllureStepResult>? steps,
    List<AllureAttachment>? attachments,
    List<AllureParameter>? parameters,
    this.start,
    this.stop,
  })  : steps = steps ?? <AllureStepResult>[],
        attachments = attachments ?? <AllureAttachment>[],
        parameters = parameters ?? <AllureParameter>[];

  /// Display name of the executable item.
  String? name;

  /// Final status of the executable item.
  AllureStatus? status;

  /// Detailed status information.
  AllureStatusDetails statusDetails;

  /// Current lifecycle stage.
  AllureStage stage;

  /// Markdown description.
  String? description;

  /// HTML description.
  String? descriptionHtml;

  /// Child steps nested under this executable item.
  final List<AllureStepResult> steps;

  /// Attachments associated with this executable item.
  final List<AllureAttachment> attachments;

  /// Parameters associated with this executable item.
  final List<AllureParameter> parameters;

  /// Start timestamp in milliseconds since epoch.
  int? start;

  /// Stop timestamp in milliseconds since epoch.
  int? stop;

  /// Converts shared executable fields to an Allure JSON map.
  Map<String, Object?> executableToJson() {
    return _compactMap<Object?>({
      'name': name,
      'status': status?.value,
      'statusDetails': statusDetails.toJson(),
      'stage': stage.value,
      'description': description,
      'descriptionHtml': descriptionHtml,
      'steps': steps.map((step) => step.toJson()).toList(),
      'attachments':
          attachments.map((attachment) => attachment.toJson()).toList(),
      'parameters': parameters.map((parameter) => parameter.toJson()).toList(),
      'start': start,
      'stop': stop,
    });
  }
}

/// Allure step result nested under a test, fixture, or another step.
class AllureStepResult extends AllureExecutable {
  /// Creates a step result.
  AllureStepResult({
    this.uuid,
    super.name,
    super.status,
    super.statusDetails = const AllureStatusDetails(),
    super.stage = AllureStage.pending,
    super.description,
    super.descriptionHtml,
    super.steps,
    super.attachments,
    super.parameters,
    super.start,
    super.stop,
  });

  /// Optional unique identifier for the step.
  String? uuid;

  /// Converts this step to the Allure JSON representation.
  Map<String, Object?> toJson() {
    return _compactMap<Object?>({
      'uuid': uuid,
      ...executableToJson(),
    });
  }
}

/// Allure fixture result used for setup and teardown records.
class AllureFixtureResult extends AllureExecutable {
  /// Creates a fixture result.
  AllureFixtureResult({
    super.name,
    super.status = AllureStatus.broken,
    super.statusDetails = const AllureStatusDetails(),
    super.stage = AllureStage.pending,
    super.description,
    super.descriptionHtml,
    super.steps,
    super.attachments,
    super.parameters,
    super.start,
    super.stop,
  });

  /// Converts this fixture to the Allure JSON representation.
  Map<String, Object?> toJson() => executableToJson();
}

/// Allure test result written as a `*-result.json` file.
class AllureTestResult extends AllureExecutable {
  /// Creates a test result.
  AllureTestResult({
    required this.uuid,
    this.historyId,
    this.fullName,
    this.testCaseId,
    this.testCaseName,
    this.titlePath,
    super.name,
    super.status,
    super.statusDetails = const AllureStatusDetails(),
    super.stage = AllureStage.pending,
    super.description,
    super.descriptionHtml,
    List<AllureLabel>? labels,
    List<AllureLink>? links,
    super.steps,
    super.attachments,
    super.parameters,
    super.start,
    super.stop,
  })  : labels = labels ?? <AllureLabel>[],
        links = links ?? <AllureLink>[];

  /// Unique identifier of the test result.
  final String uuid;

  /// Stable history identifier used by Allure to group retries and history.
  String? historyId;

  /// Fully qualified test name.
  String? fullName;

  /// Stable test case identifier.
  String? testCaseId;

  /// Human-readable test case name.
  String? testCaseName;

  /// Hierarchical title path for the test.
  List<String>? titlePath;

  /// Labels attached to the test result.
  final List<AllureLabel> labels;

  /// Links attached to the test result.
  final List<AllureLink> links;

  /// Converts this test result to the Allure JSON representation.
  Map<String, Object?> toJson() {
    return _compactMap<Object?>({
      'uuid': uuid,
      'historyId': historyId,
      'fullName': fullName,
      'testCaseId': testCaseId,
      'testCaseName': testCaseName,
      'titlePath': titlePath,
      ...executableToJson(),
      'labels': labels.map((label) => label.toJson()).toList(),
      'links': links.map((link) => link.toJson()).toList(),
    });
  }

  /// Encodes this test result as pretty-printed JSON.
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// Allure container result written as a `*-container.json` file.
class AllureTestResultContainer {
  /// Creates a test result container.
  AllureTestResultContainer({
    required this.uuid,
    this.name,
    this.description,
    this.descriptionHtml,
    List<String>? children,
    List<AllureFixtureResult>? befores,
    List<AllureFixtureResult>? afters,
    List<AllureLink>? links,
    this.start,
    this.stop,
  })  : children = children ?? <String>[],
        befores = befores ?? <AllureFixtureResult>[],
        afters = afters ?? <AllureFixtureResult>[],
        links = links ?? <AllureLink>[];

  /// Unique identifier of the container.
  final String uuid;

  /// Optional display name of the container.
  String? name;

  /// Markdown description for the container.
  String? description;

  /// HTML description for the container.
  String? descriptionHtml;

  /// Child test result UUIDs in this container.
  final List<String> children;

  /// Setup fixture results.
  final List<AllureFixtureResult> befores;

  /// Teardown fixture results.
  final List<AllureFixtureResult> afters;

  /// Links attached to the container.
  final List<AllureLink> links;

  /// Start timestamp in milliseconds since epoch.
  int? start;

  /// Stop timestamp in milliseconds since epoch.
  int? stop;

  /// Converts this container to the Allure JSON representation.
  Map<String, Object?> toJson() {
    return _compactMap<Object?>({
      'uuid': uuid,
      'name': name,
      'description': description,
      'descriptionHtml': descriptionHtml,
      'children': children,
      'befores': befores.map((fixture) => fixture.toJson()).toList(),
      'afters': afters.map((fixture) => fixture.toJson()).toList(),
      'links': links.map((link) => link.toJson()).toList(),
      'start': start,
      'stop': stop,
    });
  }
}

/// Attachment recorded outside an individual test result.
class AllureGlobalAttachment extends AllureAttachment {
  /// Creates global attachment metadata.
  const AllureGlobalAttachment({
    required super.name,
    required super.source,
    required this.timestamp,
    super.type,
    super.size,
  });

  /// Timestamp in milliseconds since epoch when the attachment was recorded.
  final int timestamp;

  /// Converts this global attachment to the Allure JSON representation.
  @override
  Map<String, Object?> toJson() {
    return _compactMap<Object?>({
      ...super.toJson(),
      'timestamp': timestamp,
    });
  }
}

/// Error recorded outside an individual test result.
class AllureGlobalError extends AllureStatusDetails {
  /// Creates a global error record.
  const AllureGlobalError({
    required this.timestamp,
    super.message,
    super.trace,
    super.known,
    super.muted,
    super.flaky,
    super.actual,
    super.expected,
  });

  /// Timestamp in milliseconds since epoch when the error was recorded.
  final int timestamp;

  /// Converts this global error to the Allure JSON representation.
  @override
  Map<String, Object?> toJson() {
    return _compactMap<Object?>({
      ...super.toJson(),
      'timestamp': timestamp,
    });
  }
}

/// Global Allure data written separately from test results.
class AllureGlobals {
  /// Creates global Allure data.
  const AllureGlobals({
    List<AllureGlobalAttachment>? attachments,
    List<AllureGlobalError>? errors,
  })  : attachments = attachments ?? const <AllureGlobalAttachment>[],
        errors = errors ?? const <AllureGlobalError>[];

  /// Global attachments to write.
  final List<AllureGlobalAttachment> attachments;

  /// Global errors to write.
  final List<AllureGlobalError> errors;

  /// Converts this global data to the Allure JSON representation.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'attachments':
          attachments.map((attachment) => attachment.toJson()).toList(),
      'errors': errors.map((error) => error.toJson()).toList(),
    };
  }
}

/// Allure category definition used by report generation.
class AllureCategory {
  /// Creates an Allure category definition.
  const AllureCategory({
    this.name,
    this.description,
    this.descriptionHtml,
    this.messageRegex,
    this.traceRegex,
    this.matchedStatuses,
    this.flaky,
  });

  /// Category display name.
  final String? name;

  /// Markdown description of the category.
  final String? description;

  /// HTML description of the category.
  final String? descriptionHtml;

  /// Message regular expression used to match results.
  final Object? messageRegex;

  /// Trace regular expression used to match results.
  final Object? traceRegex;

  /// Result statuses that match this category.
  final List<AllureStatus>? matchedStatuses;

  /// Whether this category represents flaky results.
  final bool? flaky;

  /// Converts this category to the Allure JSON representation.
  Map<String, Object?> toJson() {
    String? serializeRegex(Object? value) {
      if (value == null) {
        return null;
      }
      if (value is RegExp) {
        return value.pattern;
      }
      return value.toString();
    }

    return _compactMap<Object?>({
      'name': name,
      'description': description,
      'descriptionHtml': descriptionHtml,
      'messageRegex': serializeRegex(messageRegex),
      'traceRegex': serializeRegex(traceRegex),
      'matchedStatuses':
          matchedStatuses?.map((status) => status.value).toList(),
      'flaky': flaky,
    });
  }
}

/// Executor metadata written to `executor.json`.
class AllureExecutorInfo {
  /// Creates executor metadata.
  const AllureExecutorInfo({
    this.reportName,
    this.buildOrder,
    this.reportUrl,
    this.name,
    this.type,
    this.buildName,
    this.buildUrl,
  });

  /// Name of the generated report.
  final String? reportName;

  /// Numeric build order for report history.
  final int? buildOrder;

  /// URL of the generated report.
  final String? reportUrl;

  /// Name of the executor, such as a CI system.
  final String? name;

  /// Type of executor.
  final String? type;

  /// Name of the build.
  final String? buildName;

  /// URL of the build.
  final String? buildUrl;

  /// Converts this executor metadata to the Allure JSON representation.
  Map<String, Object?> toJson() {
    return _compactMap<Object?>({
      'reportName': reportName,
      'buildOrder': buildOrder,
      'reportUrl': reportUrl,
      'name': name,
      'type': type,
      'buildName': buildName,
      'buildUrl': buildUrl,
    });
  }
}

/// Environment properties written to `environment.properties`.
typedef AllureEnvironmentInfo = Map<String, String?>;

Map<String, T> _compactMap<T>(Map<String, T?> value) {
  value.removeWhere((_, item) => item == null);
  return value.cast<String, T>();
}
