import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/entitlements/entitlement_providers.dart';
import '../../../../core/entitlements/paywall_navigation.dart';
import '../../../../core/entitlements/paywall_trigger.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/tinted_chip.dart';

/// The `--r-pill` chip beside an AI action (`docs/landing_page/67-mobile-free-pro-plan.md`
/// §3.4, `69` §4.3): `aiCreditsRemaining` as a bare number, turning
/// `secondary`-toned at one credit left and `error`-toned with the
/// calendar-month refill date at zero (`69` DV-11). Renders nothing when
/// [aiCreditsProvider] is `null` — unlimited, either Pro or an
/// unresolved/fail-open snapshot (D-P4).
///
/// Never disabled (`69` DV-12: "the chip never disables the control") — at
/// zero it's tappable and opens the paywall; above zero it's a plain
/// indicator, since the real AI action itself is the control, gated
/// separately by [requireAiCredits].
class AiCreditChip extends ConsumerWidget {
  const AiCreditChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = ref.watch(aiCreditsProvider);
    if (remaining == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final exhausted = remaining == 0;

    // A design-system tinted chip (R2.9): the theme's heart at zero, the clay
    // role mark at one credit, plain secondary text colour otherwise.
    final Color color;
    if (exhausted) {
      color = context.metricColors.heart;
    } else if (remaining == 1) {
      color = context.palette.role;
    } else {
      color = context.palette.text2;
    }

    final label = exhausted
        ? l10n.aiCreditsRefillDateMessage(_refillDateLabel(context))
        : '$remaining';

    // One clean semantics node with the full sentence, rather than a screen
    // reader announcing the bare visible number (e.g. "3") on top of it —
    // ExcludeSemantics hides the chip's own nodes; `button`/`onTap` here
    // re-adds the "tappable" announcement for the exhausted state that
    // ExcludeSemantics would otherwise also hide.
    final chip = ExcludeSemantics(child: TintedChip(label: label, color: color));
    return Semantics(
      label: l10n.aiCreditsRemainingSemanticsLabel(remaining),
      button: exhausted,
      onTap: exhausted ? () => openPaywall(context, PaywallTrigger.aiCredits) : null,
      // Only the exhausted state is a real control — see class doc.
      child: exhausted
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => openPaywall(context, PaywallTrigger.aiCredits),
              child: chip,
            )
          : chip,
    );
  }

  /// The next calendar-month boundary — matches the backend's counter, keyed
  /// by `year_month` (`64` §3.4) — formatted with the month's full name for
  /// the current locale (`69` DV-11's "Szeptember 1-jén" example).
  String _refillDateLabel(BuildContext context) {
    final now = DateTime.now();
    final refillsOn = DateTime(now.year, now.month + 1, 1);
    final locale = Localizations.localeOf(context).languageCode;
    return DateFormat.MMMMd(locale).format(refillsOn);
  }
}
