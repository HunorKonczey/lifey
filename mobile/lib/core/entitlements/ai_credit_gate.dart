import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'entitlement_providers.dart';
import 'paywall_navigation.dart';
import 'paywall_trigger.dart';

/// Call before starting an AI action (meal-photo estimation, recipe
/// generation, ...) that would spend an AI credit
/// (`docs/landing_page/67-mobile-free-pro-plan.md` §3.4). Returns `true`
/// when the action may proceed. At zero remaining credits, opens the
/// paywall with [PaywallTrigger.aiCredits] instead and returns `false`.
///
/// This is a courtesy check only — `aiCreditsRemaining` is a display field,
/// not the enforcement (D-P5). The server's own `402` on the actual request
/// is authoritative; a caller that gets one back (credits spent by another
/// device between this check and the request landing, for instance) should
/// react the same way this function does: `openPaywall(context,
/// PaywallTrigger.aiCredits)`.
bool requireAiCredits(BuildContext context, WidgetRef ref) {
  final remaining = ref.read(aiCreditsProvider);
  if (remaining == 0) {
    openPaywall(context, PaywallTrigger.aiCredits);
    return false;
  }
  return true;
}
