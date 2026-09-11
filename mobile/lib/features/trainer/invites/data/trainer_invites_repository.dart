import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../domain/sent_invite.dart';

/// The trainer's side of inviting someone (docs/chat/41-trainer-mobile-v2-plan.md
/// T7). The client's side — seeing and accepting the invite — has been in the
/// app since the original trainer work (`features/trainer_invite`).
class TrainerInvitesRepository {
  TrainerInvitesRepository(this._dio);

  final Dio _dio;

  /// Pending, non-expired invites only. An expired one simply stops being
  /// listed; there is nothing for the trainer to do about it but send another.
  Future<List<SentInvite>> findPending() async {
    final response = await _dio.get<List<dynamic>>(ApiEndpoints.trainerInvites);
    return (response.data ?? [])
        .map((json) => SentInvite.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Invites by exact email address. The backend rejects an address that is
  /// already a client, already invited, or the trainer's own.
  Future<SentInvite> invite(String email) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.trainerInvites,
      data: {'email': email},
    );
    return SentInvite.fromJson(response.data ?? const {});
  }

  Future<void> cancel(int inviteId) =>
      _dio.delete<void>(ApiEndpoints.trainerInvite(inviteId));
}

final trainerInvitesRepositoryProvider = Provider<TrainerInvitesRepository>((ref) {
  return TrainerInvitesRepository(ref.watch(dioClientProvider));
});
