import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../client_detail/data/client_detail_repository.dart' show ClientDetailRepository;
import '../domain/schedule.dart';

/// The widest window `GET /trainer/scheduled-sessions` accepts. The backend
/// refuses anything longer, so the calendar never asks for more.
const int maxCalendarRangeDays = 62;

/// Trainer-side scheduling (docs/chat/41-trainer-mobile-v2-plan.md T5).
///
/// Online-only, like the rest of the trainer surface, and for the sharpest
/// version of the reason: these writes put sessions into *other people's*
/// calendars. A queued schedule that syncs two days late is a client standing
/// in a gym on the wrong evening.
class ScheduleRepository {
  ScheduleRepository(this._dio);

  final Dio _dio;

  /// One client's schedules, newest series first as the backend returns them.
  Future<List<ScheduleSummary>> findSchedulesForClient(int clientId) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.trainerClientSchedules(clientId),
    );
    return (response.data ?? [])
        .map((json) => ScheduleSummary.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// One client's occurrences in a range — the client detail's schedule tab.
  Future<List<CalendarSession>> findOccurrencesForClient(
    int clientId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.trainerClientScheduledSessions(clientId),
      queryParameters: _range(from, to),
    );
    return (response.data ?? [])
        .map((json) => CalendarSession.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Every client's occurrences in a range — the calendar branch.
  Future<List<CalendarSession>> findOccurrences({
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.trainerScheduledSessions,
      queryParameters: _range(from, to),
    );
    return (response.data ?? [])
        .map((json) => CalendarSession.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Creates the series and every occurrence in it, in one call.
  ///
  /// `endDate` is sent even for a one-off: the column is NOT NULL for every
  /// recurrence, and the server ignores the value in that case.
  Future<void> createSchedule({
    required int clientId,
    required int templateId,
    required ScheduleRecurrence recurrence,
    required List<ScheduleWeekday> daysOfWeek,
    required DateTime startDate,
    required DateTime endDate,
    ScheduleTime? timeOfDay,
  }) {
    return _dio.post<Map<String, dynamic>>(
      ApiEndpoints.trainerSchedules,
      data: {
        'clientId': clientId,
        'templateId': templateId,
        'recurrence': recurrence.apiValue,
        'daysOfWeek': [for (final day in daysOfWeek) day.apiValue],
        if (timeOfDay != null) 'timeOfDay': timeOfDay.apiValue,
        'startDate': ClientDetailRepository.formatDate(startDate),
        'endDate': ClientDetailRepository.formatDate(endDate),
      },
    );
  }

  /// Calls off the whole series. Only its future occurrences go; what already
  /// happened stays on the record.
  Future<void> cancelSchedule(int scheduleId) =>
      _dio.delete<void>(ApiEndpoints.trainerSchedule(scheduleId));

  /// Calls off one occurrence. 409 if it has already started or passed —
  /// which is why the UI only offers this on an upcoming one.
  Future<void> cancelOccurrence(int sessionId) =>
      _dio.delete<void>(ApiEndpoints.trainerScheduledSession(sessionId));

  Map<String, String> _range(DateTime from, DateTime to) => {
        'from': ClientDetailRepository.formatDate(from),
        'to': ClientDetailRepository.formatDate(to),
      };
}

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository(ref.watch(dioClientProvider));
});
