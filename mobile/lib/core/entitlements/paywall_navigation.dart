import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'paywall_trigger.dart';

/// Opens the paywall (`67` §4.3) with [trigger]. Every gated surface calls
/// this rather than pushing `/paywall` itself, so the route can change without
/// touching them (the screen behind it is `PaywallScreen`, `69` §3).
void openPaywall(BuildContext context, PaywallTrigger trigger) {
  context.push('/paywall', extra: trigger);
}
