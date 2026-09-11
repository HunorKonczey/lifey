import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../domain/trainer_client.dart';

/// Online-only read of the trainer's active clients.
///
/// Never cached to disk: the trainer surface is online-first
/// (docs/chat/41-trainer-mobile-v2-plan.md §2.2), so this is re-fetched on
/// entry and on pull-to-refresh rather than synced.
///
/// One response already carries the compliance facts the list needs
/// (`lastActivityAt`, `lastWeightAt`, `missedWorkoutCount`) — no second
/// round-trip per client, so the plan's §5.2 "combined endpoint" backend item
/// turned out to be unnecessary.
class TrainerClientsRepository {
  TrainerClientsRepository(this._dio);

  final Dio _dio;

  Future<List<TrainerClient>> fetchActiveClients() async {
    final response = await _dio.get<List<dynamic>>(ApiEndpoints.trainerClients);
    return (response.data ?? [])
        .map((json) => TrainerClient.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

final trainerClientsRepositoryProvider = Provider<TrainerClientsRepository>((ref) {
  // The MAIN api client, not chatDioProvider: this calls /trainer/clients,
  // which lifey-api owns; the chat service has no such route
  // (docs/chat/44-chat-service-extraction-plan.md §7.2).
  return TrainerClientsRepository(ref.watch(dioClientProvider));
});
