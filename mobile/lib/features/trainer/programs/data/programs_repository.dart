import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../client_detail/data/client_detail_repository.dart' show ClientDetailRepository;
import '../domain/program.dart';

/// Multi-week programs, read and assigned (docs/chat/41-trainer-mobile-v2-plan.md
/// T6, docs/34-multi-week-program-plan.md).
///
/// There is deliberately no create or update here. Authoring a program is a
/// desk job that stays on the web — the reasoning is on the programs screen,
/// where the trainer can read it.
class ProgramsRepository {
  ProgramsRepository(this._dio);

  final Dio _dio;

  Future<List<ProgramSummary>> findAll() async {
    final response = await _dio.get<List<dynamic>>(ApiEndpoints.trainerPrograms);
    return (response.data ?? [])
        .map((json) => ProgramSummary.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Program> findById(int programId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.trainerProgram(programId),
    );
    return Program.fromJson(response.data ?? const {});
  }

  /// Starts one client on the program. The backend materializes every slot of
  /// the grid as an upcoming session from [startDate], which must be a Monday
  /// and not in the past.
  ///
  /// One client per call, because that is how the endpoint is shaped. A
  /// multi-client version would be several independent calls with real partial
  /// failure — unlike content assignment, there is no batch transaction here
  /// to hide behind.
  Future<ProgramAssignmentResult> assign({
    required int programId,
    required int clientId,
    required DateTime startDate,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.trainerProgramAssignments(programId),
      data: {
        'clientId': clientId,
        'startDate': ClientDetailRepository.formatDate(startDate),
      },
    );
    return ProgramAssignmentResult.fromJson(response.data ?? const {});
  }

  Future<List<ProgramAssignmentSummary>> findAssignmentsForClient(int clientId) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.trainerClientProgramAssignments(clientId),
    );
    return (response.data ?? [])
        .map((json) => ProgramAssignmentSummary.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Stops a run. Only its future, not-yet-started occurrences go; what the
  /// client already did stays on their record.
  Future<void> cancelAssignment(int assignmentId) =>
      _dio.delete<void>(ApiEndpoints.trainerProgramAssignment(assignmentId));
}

final programsRepositoryProvider = Provider<ProgramsRepository>((ref) {
  return ProgramsRepository(ref.watch(dioClientProvider));
});
