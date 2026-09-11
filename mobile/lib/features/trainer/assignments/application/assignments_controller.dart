import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clients/application/trainer_clients_controller.dart';
import '../../clients/domain/trainer_client.dart';
import '../data/assignments_repository.dart';
import '../domain/assignment.dart';

/// One assigned piece of content, and who has it.
class AssignmentRow {
  const AssignmentRow({required this.assignment, required this.client});

  final Assignment assignment;
  final TrainerClient client;
}

/// Everything this trainer has assigned, across every client.
///
/// Built by asking each client's endpoint in turn, because there is no
/// "everything I assigned" endpoint — `/trainer/assignments/clients` answers a
/// different question (who holds *this* content). The web admin's page fans
/// out exactly the same way, so this is parity rather than a shortcut; it is
/// also the one place in the trainer view where the request count grows with
/// the roster, and a single endpoint is the fix if that ever bites.
class AssignmentsController extends AsyncNotifier<List<AssignmentRow>> {
  @override
  Future<List<AssignmentRow>> build() async {
    final clients = await ref.watch(trainerClientsControllerProvider.future);
    if (clients.isEmpty) return const [];

    final repo = ref.read(assignmentsRepositoryProvider);
    // In parallel: sequential would make a 20-client roster twenty
    // round-trips deep before the first row appears.
    final perClient = await Future.wait(
      clients.map((client) => repo.findForClient(client.userId)),
    );

    final rows = <AssignmentRow>[];
    for (var i = 0; i < clients.length; i++) {
      for (final assignment in perClient[i]) {
        rows.add(AssignmentRow(assignment: assignment, client: clients[i]));
      }
    }
    rows.sort((a, b) => b.assignment.assignedAt.compareTo(a.assignment.assignedAt));
    return rows;
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }

  /// Hands content to one or more clients, then reloads so the new rows show.
  /// Throws on a rejected request — the whole batch failed, and the sheet is
  /// the place that says so.
  Future<BulkAssignmentResult> assign({
    required AssignableContentType contentType,
    required int sourceId,
    required List<int> clientIds,
  }) async {
    final result = await ref.read(assignmentsRepositoryProvider).assign(
          contentType: contentType,
          sourceId: sourceId,
          clientIds: clientIds,
        );
    await refresh();
    return result;
  }

  /// Removes an assignment and the client's copy with it.
  Future<void> unassign(int assignmentId) async {
    await ref.read(assignmentsRepositoryProvider).unassign(assignmentId);
    state = AsyncData([
      for (final row in state.value ?? const <AssignmentRow>[])
        if (row.assignment.id != assignmentId) row,
    ]);
  }
}

final assignmentsControllerProvider =
    AsyncNotifierProvider<AssignmentsController, List<AssignmentRow>>(
  AssignmentsController.new,
);

/// What the list is filtered down to. In-memory, like the client list's sort:
/// it is view state, and the web keeps it the same way.
class AssignmentFilter {
  const AssignmentFilter({this.clientId, this.contentType});

  /// null means every client.
  final int? clientId;

  /// null means both kinds.
  final AssignableContentType? contentType;

  bool matches(AssignmentRow row) {
    if (clientId != null && row.client.userId != clientId) return false;
    if (contentType != null && row.assignment.contentType != contentType) {
      return false;
    }
    return true;
  }

  AssignmentFilter copyWith({
    int? clientId,
    AssignableContentType? contentType,
    bool clearClient = false,
    bool clearType = false,
  }) {
    return AssignmentFilter(
      clientId: clearClient ? null : (clientId ?? this.clientId),
      contentType: clearType ? null : (contentType ?? this.contentType),
    );
  }
}

class AssignmentFilterController extends Notifier<AssignmentFilter> {
  @override
  AssignmentFilter build() => const AssignmentFilter();

  void selectClient(int? clientId) => state = clientId == null
      ? state.copyWith(clearClient: true)
      : state.copyWith(clientId: clientId);

  void selectType(AssignableContentType? type) => state = type == null
      ? state.copyWith(clearType: true)
      : state.copyWith(contentType: type);
}

final assignmentFilterControllerProvider =
    NotifierProvider<AssignmentFilterController, AssignmentFilter>(
  AssignmentFilterController.new,
);
