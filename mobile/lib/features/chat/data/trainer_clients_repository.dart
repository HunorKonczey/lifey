import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../domain/trainer_client_option.dart';

/// Online-only read of the trainer's active clients, for the chat "new
/// conversation" picker. Never cached: it is only ever consulted while the
/// sheet is open, and a stale client list would be worse than a spinner.
///
/// Lives in the chat feature rather than a trainer one because in v1 the
/// conversation list *is* the trainer's mobile surface — the rest of the
/// trainer screens are the v2 plan's scope
/// (docs/chat/41-trainer-mobile-v2-plan.md).
class TrainerClientsRepository {
  TrainerClientsRepository(this._dio);

  final Dio _dio;

  Future<List<TrainerClientOption>> fetchActiveClients() async {
    final response = await _dio.get<List<dynamic>>(ApiEndpoints.trainerClients);
    return (response.data ?? [])
        .map((json) => TrainerClientOption.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

final trainerClientsRepositoryProvider = Provider<TrainerClientsRepository>((ref) {
  // The MAIN api client, not chatDioProvider — despite living under
  // features/chat/. This calls /trainer/clients, which lifey-api owns; the chat
  // service has no such route (docs/chat/44-chat-service-extraction-plan.md §7.2).
  return TrainerClientsRepository(ref.watch(dioClientProvider));
});
