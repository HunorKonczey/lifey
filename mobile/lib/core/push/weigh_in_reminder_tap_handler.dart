import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notifications/notification_service.dart';
import '../router/app_router.dart';

/// Routes a tap on the daily weigh-in reminder notification to the weight
/// tab, same pattern as [PushTapHandler] for server-sent pushes.
class WeighInReminderTapHandler {
  WeighInReminderTapHandler(this._ref) {
    NotificationService.setWeighInReminderTapHandler(_route);
  }

  final Ref _ref;

  void dispose() {
    NotificationService.setWeighInReminderTapHandler(null);
  }

  void _route() {
    _ref.read(appRouterProvider).go('/weight');
  }
}

final weighInReminderTapHandlerProvider = Provider<WeighInReminderTapHandler>((ref) {
  final handler = WeighInReminderTapHandler(ref);
  ref.onDispose(handler.dispose);
  return handler;
});
