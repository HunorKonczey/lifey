import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../domain/trainer_invite.dart';

/// Online-only read of the current user's pending trainer invites — never
/// persisted locally, always re-fetched on app start/resume (see
/// docs/personal_trainer/05-mobil-terv.md).
class TrainerInviteRepository {
  TrainerInviteRepository(this._dio);

  final Dio _dio;

  Future<List<TrainerInvite>> fetchPending() async {
    final response = await _dio.get<List<dynamic>>(ApiEndpoints.trainerInvitesPending);
    return (response.data ?? [])
        .map((json) => TrainerInvite.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> respond(int inviteId, {required bool accept}) {
    return _dio.post<void>(
      ApiEndpoints.trainerInviteRespond(inviteId),
      data: {'accept': accept},
    );
  }
}

final trainerInviteRepositoryProvider = Provider<TrainerInviteRepository>((ref) {
  return TrainerInviteRepository(ref.watch(dioClientProvider));
});
