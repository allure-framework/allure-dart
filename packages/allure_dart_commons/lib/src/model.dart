import 'dart:convert';

enum AllureStatus {
  failed,
  broken,
  passed,
  skipped;

  String get value => name;
}

enum AllureStage {
  scheduled,
  running,
  finished,
  pending,
  interrupted;

  String get value => name;
}

enum AllureParameterMode {
  defaultMode('default'),
  masked('masked'),
  hidden('hidden');

  const AllureParameterMode(this.value);

  final String value;
}

class AllureLabel {
  const AllureLabel({required this.name, required this.value});

  final String name;
  final String value;

  Map<String, String> toJson() =>
      <String, String>{'name': name, 'value': value};
}

class AllureLink {
  const AllureLink({
    required this.url,
    this.name,
    this.type,
  });

  final String url;
  final String? name;
  final String? type;

  Map<String, String> toJson() {
    return _compactMap<String>({
      'url': url,
      'name': name,
      'type': type,
    });
  }
}

class AllureParameter {
  const AllureParameter({
    required this.name,
    required this.value,
    this.excluded,
    this.mode,
  });

  final String name;
  final String value;
  final bool? excluded;
  final AllureParameterMode? mode;

  Map<String, Object?> toJson() {
    return _compactMap<Object?>({
      'name': name,
      'value': value,
      'excluded': excluded,
      'mode': mode?.value,
    });
  }
}

class AllureAttachment {
  const AllureAttachment({
    required this.name,
    required this.source,
    this.type,
    this.size,
  });

  final String name;
  final String source;
  final String? type;
  final int? size;

  Map<String, Object?> toJson() {
    return _compactMap<Object?>({
      'name': name,
      'source': source,
      'type': type,
      'size': size,
    });
  }
}

class AllureStatusDetails {
  const AllureStatusDetails({
    this.message,
    this.trace,
    this.known,
    this.muted,
    this.flaky,
    this.actual,
    this.expected,
  });

  final String? message;
  final String? trace;
  final bool? known;
  final bool? muted;
  final bool? flaky;
  final String? actual;
  final String? expected;

  bool get isEmpty =>
      message == null &&
      trace == null &&
      known == null &&
      muted == null &&
      flaky == null &&
      actual == null &&
      expected == null;

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

abstract class AllureExecutable {
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

  String? name;
  AllureStatus? status;
  AllureStatusDetails statusDetails;
  AllureStage stage;
  String? description;
  String? descriptionHtml;
  final List<AllureStepResult> steps;
  final List<AllureAttachment> attachments;
  final List<AllureParameter> parameters;
  int? start;
  int? stop;

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

class AllureStepResult extends AllureExecutable {
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

  String? uuid;

  Map<String, Object?> toJson() {
    return _compactMap<Object?>({
      'uuid': uuid,
      ...executableToJson(),
    });
  }
}

class AllureFixtureResult extends AllureExecutable {
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

  Map<String, Object?> toJson() => executableToJson();
}

class AllureTestResult extends AllureExecutable {
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

  final String uuid;
  String? historyId;
  String? fullName;
  String? testCaseId;
  String? testCaseName;
  List<String>? titlePath;
  final List<AllureLabel> labels;
  final List<AllureLink> links;

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

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());
}

class AllureTestResultContainer {
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

  final String uuid;
  String? name;
  String? description;
  String? descriptionHtml;
  final List<String> children;
  final List<AllureFixtureResult> befores;
  final List<AllureFixtureResult> afters;
  final List<AllureLink> links;
  int? start;
  int? stop;

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

class AllureGlobalAttachment extends AllureAttachment {
  const AllureGlobalAttachment({
    required super.name,
    required super.source,
    required this.timestamp,
    super.type,
    super.size,
  });

  final int timestamp;

  @override
  Map<String, Object?> toJson() {
    return _compactMap<Object?>({
      ...super.toJson(),
      'timestamp': timestamp,
    });
  }
}

class AllureGlobalError extends AllureStatusDetails {
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

  final int timestamp;

  @override
  Map<String, Object?> toJson() {
    return _compactMap<Object?>({
      ...super.toJson(),
      'timestamp': timestamp,
    });
  }
}

class AllureGlobals {
  const AllureGlobals({
    List<AllureGlobalAttachment>? attachments,
    List<AllureGlobalError>? errors,
  })  : attachments = attachments ?? const <AllureGlobalAttachment>[],
        errors = errors ?? const <AllureGlobalError>[];

  final List<AllureGlobalAttachment> attachments;
  final List<AllureGlobalError> errors;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'attachments':
          attachments.map((attachment) => attachment.toJson()).toList(),
      'errors': errors.map((error) => error.toJson()).toList(),
    };
  }
}

class AllureCategory {
  const AllureCategory({
    this.name,
    this.description,
    this.descriptionHtml,
    this.messageRegex,
    this.traceRegex,
    this.matchedStatuses,
    this.flaky,
  });

  final String? name;
  final String? description;
  final String? descriptionHtml;
  final Object? messageRegex;
  final Object? traceRegex;
  final List<AllureStatus>? matchedStatuses;
  final bool? flaky;

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

class AllureExecutorInfo {
  const AllureExecutorInfo({
    this.reportName,
    this.buildOrder,
    this.reportUrl,
    this.name,
    this.type,
    this.buildName,
    this.buildUrl,
  });

  final String? reportName;
  final int? buildOrder;
  final String? reportUrl;
  final String? name;
  final String? type;
  final String? buildName;
  final String? buildUrl;

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

typedef AllureEnvironmentInfo = Map<String, String?>;

Map<String, T> _compactMap<T>(Map<String, T?> value) {
  value.removeWhere((_, item) => item == null);
  return value.cast<String, T>();
}
