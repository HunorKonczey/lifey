import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'paywall_trigger.dart';

/// Opens the paywall (`67` §4.3) with [trigger]. Every gated surface calls
/// this rather than pushing `/paywall` itself, so they don't need to change
/// again once Prompt 6 builds the real screen (`69` §3) behind that route —
/// until then it's `app_router.dart`'s [PlaceholderScreen].
void openPaywall(BuildContext context, PaywallTrigger trigger) {
  context.push('/paywall', extra: trigger);
}
