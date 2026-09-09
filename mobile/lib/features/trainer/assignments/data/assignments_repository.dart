import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../domain/assignment.dart';

/// Handing the trainer's own content to their clients
/// (docs/chat/41-trainer-mobile-v2-plan.md T4).
///
/// Online-only like the rest of the trainer surface: an assignment is a write
/// against *another person's* account, and the plan is explicit that queuing
/// those offline is the wrong trade (§2.2) — a programme the trainer believes
/// they sent two days ago cannot be un-believed.
class AssignmentsRepository {
  AssignmentsRepository(this._dio);

  final Dio _dio;

  Future<List<Assignment>> findForClient(int clientId) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.trainerClientAssignments(clientId),
    );
    return (response.data ?? [])
        .map((json) => Assignment.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Client ids that already hold this content, so the picker can lock them.
  Future<List<int>> findClientIdsHolding(
    AssignableContentType contentType,
    int sourceId,
  ) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.trainerAssignmentClients,
      queryParameters: {
        'contentType': contentType.apiValue,
        'sourceId': sourceId,
      },
    );
    return (response.data ?? []).map((e) => (e as num).toInt()).toList();
  }

  /// One transaction for the whole batch: every client gets it, or none does
  /// and the call throws. A client who already holds the content comes back
  /// in `skippedClientIds` rather than failing anything.
  Future<BulkAssignmentResult> assign({
    required AssignableContentType contentType,
    required int sourceId,
    required List<int> clientIds,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.trainerAssignments,
      data: {
        'clientIds': clientIds,
        'contentType': contentType.apiValue,
        'sourceId': sourceId,
      },
    );
    return BulkAssignmentResult.fromJson(response.data ?? const {});
  }

  /// Also soft-deletes the copy in the client's account, which is why the UI
  /// asks first.
  Future<void> unassign(int assignmentId) {
    return _dio.delete<void>(ApiEndpoints.trainerAssignment(assignmentId));
  }
}

final assignmentsRepositoryProvider = Provider<AssignmentsRepository>((ref) {
  return AssignmentsRepository(ref.watch(dioClientProvider));
});
