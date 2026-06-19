import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fired by [AuthInterceptor] when a token refresh fails, so the auth feature
/// can clear its signed-in state without core/network code depending on it.
class SessionExpiredNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void notify() => state++;
}

final sessionExpiredProvider =
    NotifierProvider<SessionExpiredNotifier, int>(SessionExpiredNotifier.new);
