import 'package:flutter/material.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../domain/compliance.dart';
import '../../domain/trainer_client.dart';

/// The one line that says how a client is doing — "Active today", "Last seen 4
/// days ago", "Weigh-in due" — and the colour of its dot.
class ClientStatus {
  const ClientStatus(this.label, this.color);

  final String label;
  final Color color;
}

/// Reads the status off [client] at [now] (one instant for the whole list, so
/// the sort, the chips and this line never disagree).
///
/// Green while they are around, the warning colour once they have gone quiet
/// (the compliance threshold), grey when there is nothing to judge yet. With
/// [weighInFirst] a client who is otherwise active but overdue for a weigh-in is
/// told so in the weight blue — the compact tablet row has no chips to say it.
ClientStatus clientStatusOf(
  BuildContext context,
  TrainerClient client,
  DateTime now, {
  bool weighInFirst = false,
}) {
  final l10n = AppLocalizations.of(context)!;
  final p = context.palette;
  final mc = context.metricColors;
  final flags = complianceFor(client, now: now);

  final lastActivityAt = client.lastActivityAt;
  final days = lastActivityAt == null ? null : _wholeDaysBetween(lastActivityAt, now);
  final label = days == null
      ? l10n.trainerClientNoActivityLabel
      : days == 0
          ? l10n.trainerClientActiveTodayLabel
          : days == 1
              ? l10n.trainerClientActiveYesterdayLabel
              : l10n.trainerClientLastSeenLabel(days);

  if (weighInFirst && !flags.inactive && flags.weightStale && days != null) {
    return ClientStatus(l10n.trainerClientChipWeighInDue, mc.weight);
  }
  return ClientStatus(label, flags.inactive ? mc.calories : (days == null ? p.text2 : mc.improvement));
}

int _wholeDaysBetween(DateTime from, DateTime to) {
  final elapsedMs = to.millisecondsSinceEpoch - from.millisecondsSinceEpoch;
  if (elapsedMs < 0) return 0;
  return elapsedMs ~/ const Duration(days: 1).inMilliseconds;
}
