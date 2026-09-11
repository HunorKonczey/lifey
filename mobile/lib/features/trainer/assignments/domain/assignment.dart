import '../../clients/domain/trainer_client.dart' show parseTrainerTimestamp;

/// What a trainer can hand a client: one of their own workout templates, or
/// one of their own recipes.
enum AssignableContentType {
  template('TEMPLATE'),
  recipe('RECIPE');

  const AssignableContentType(this.apiValue);

  final String apiValue;

  static AssignableContentType fromApi(String value) => values.firstWhere(
        (type) => type.apiValue == value,
        orElse: () => AssignableContentType.template,
      );
}

/// One row of `GET /trainer/clients/{id}/assignments`.
///
/// Carries no name: the backend reports *what was assigned by id*, and the
/// UI resolves it against the trainer's own template and recipe lists — which
/// on this client are already local, so no extra request is needed. A source
/// the trainer has since deleted therefore has no name to show, which is why
/// [Assignment] deliberately keeps `sourceId` rather than pretending.
class Assignment {
  const Assignment({
    required this.id,
    required this.contentType,
    required this.sourceId,
    required this.copiedId,
    required this.assignedAt,
  });

  final int id;
  final AssignableContentType contentType;

  /// The trainer's own template/recipe this copy came from.
  final int sourceId;

  /// The client's copy. Not shown anywhere yet — kept because unassigning
  /// soft-deletes it, and a future "open their copy" needs it.
  final int copiedId;

  final DateTime assignedAt;

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: (json['id'] as num).toInt(),
      contentType: AssignableContentType.fromApi(json['contentType'] as String),
      sourceId: (json['sourceId'] as num).toInt(),
      copiedId: (json['copiedId'] as num?)?.toInt() ?? 0,
      assignedAt: parseTrainerTimestamp(json['assignedAt'] as String),
    );
  }
}

/// What `POST /trainer/assignments` did.
///
/// Not a partial-failure report: the whole batch is one transaction
/// (docs/35-bulk-assignment-plan.md), so either every requested client was
/// handled or nothing was written at all. The only per-client outcome is a
/// **skip** — that client already holds this content — and a skip is a
/// result, not an error: it is what makes a retry safe.
class BulkAssignmentResult {
  const BulkAssignmentResult({
    this.assignedClientIds = const [],
    this.skippedClientIds = const [],
  });

  final List<int> assignedClientIds;
  final List<int> skippedClientIds;

  int get requestedCount => assignedClientIds.length + skippedClientIds.length;

  factory BulkAssignmentResult.fromJson(Map<String, dynamic> json) {
    return BulkAssignmentResult(
      assignedClientIds: ((json['assignments'] as List<dynamic>?) ?? const [])
          .map((e) => ((e as Map<String, dynamic>)['clientId'] as num).toInt())
          .toList(),
      skippedClientIds: ((json['skippedClientIds'] as List<dynamic>?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
    );
  }
}

/// A template or recipe the trainer can hand out, flattened so the picker
/// does not care which of the two it is holding.
class AssignableContent {
  const AssignableContent({
    required this.type,
    required this.sourceId,
    required this.name,
  });

  final AssignableContentType type;
  final int sourceId;
  final String name;
}
