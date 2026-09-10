import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../schedule/application/calendar_controller.dart';
import '../../schedule/application/client_schedules_controller.dart';
import '../data/programs_repository.dart';
import '../domain/program.dart';

/// The trainer's program library.
final programsProvider = FutureProvider<List<ProgramSummary>>((ref) {
  return ref.watch(programsRepositoryProvider).findAll();
});

/// One program's full grid.
final programProvider = FutureProvider.family<Program, int>((ref, programId) {
  return ref.watch(programsRepositoryProvider).findById(programId);
});

/// One client's program runs.
final clientProgramAssignmentsProvider =
    FutureProvider.family<List<ProgramAssignmentSummary>, int>((ref, clientId) {
  return ref.watch(programsRepositoryProvider).findAssignmentsForClient(clientId);
});

/// Starts a client on a program, then refreshes everything that just changed.
///
/// Assigning writes sessions into the client's calendar, so the calendar and
/// the client's own schedule tab are both now stale — which is why this lives
/// in one place instead of each caller remembering the list.
final assignProgramProvider = Provider<
    Future<ProgramAssignmentResult> Function({
  required int programId,
  required int clientId,
  required DateTime startDate,
})>((ref) {
  return ({
    required int programId,
    required int clientId,
    required DateTime startDate,
  }) async {
    final result = await ref.read(programsRepositoryProvider).assign(
          programId: programId,
          clientId: clientId,
          startDate: startDate,
        );
    ref.invalidate(programsProvider);
    ref.invalidate(clientProgramAssignmentsProvider(clientId));
    ref.invalidate(clientUpcomingOccurrencesProvider(clientId));
    ref.invalidate(calendarSessionsProvider);
    return result;
  };
});

/// Stops a run, and refreshes the same set for the same reason.
final cancelProgramAssignmentProvider =
    Provider<Future<void> Function(int clientId, int assignmentId)>((ref) {
  return (clientId, assignmentId) async {
    await ref.read(programsRepositoryProvider).cancelAssignment(assignmentId);
    ref.invalidate(programsProvider);
    ref.invalidate(clientProgramAssignmentsProvider(clientId));
    ref.invalidate(clientUpcomingOccurrencesProvider(clientId));
    ref.invalidate(calendarSessionsProvider);
  };
});
