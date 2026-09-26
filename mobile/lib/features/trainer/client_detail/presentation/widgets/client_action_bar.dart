import 'package:flutter/material.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';

/// "Message" and "Schedule" right under the tabs (canvas Lifey 6, client
/// overview: "akció elöl") — the two things a trainer does *to* a client, one
/// tap from every tab instead of a menu or a floating button in the way of the
/// list. Message is the quiet outlined button, Schedule the primary one.
class ClientActionBar extends StatelessWidget {
  const ClientActionBar({
    super.key,
    required this.onMessage,
    required this.onSchedule,
    this.busy = false,
  });

  final VoidCallback onMessage;
  final VoidCallback onSchedule;

  /// The chat is opening; Message waits for it instead of opening twice.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s12, AppSpacing.screen, AppSpacing.s4),
      child: ClientActionButtons(onMessage: onMessage, onSchedule: onSchedule, busy: busy),
    );
  }
}

/// The two buttons themselves. [expand] shares the row between them (the
/// phone's bar); without it each keeps its natural width, at least 140 / 150 dp
/// as in the tablet canvas, so they sit at the end of the wide header.
class ClientActionButtons extends StatelessWidget {
  const ClientActionButtons({
    super.key,
    required this.onMessage,
    required this.onSchedule,
    this.busy = false,
    this.expand = true,
  });

  final VoidCallback onMessage;
  final VoidCallback onSchedule;
  final bool busy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final message = OutlinedButton.icon(
      onPressed: busy ? null : onMessage,
      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
      label: _Label(l10n.trainerMessageClientButton),
      style: expand ? null : OutlinedButton.styleFrom(minimumSize: const Size(140, 48)),
    );
    final schedule = FilledButton.icon(
      onPressed: onSchedule,
      icon: const Icon(Icons.event_outlined, size: 22),
      label: _Label(l10n.trainerScheduleWorkoutAction),
      style: expand ? null : FilledButton.styleFrom(minimumSize: const Size(150, 48)),
    );
    return Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        expand ? Expanded(child: message) : message,
        const SizedBox(width: 10),
        expand ? Expanded(child: schedule) : schedule,
      ],
    );
  }
}

/// A button caption that shrinks to fit instead of ending in "…": two buttons
/// share the row, and Hungarian "Ütemezés" at 130 % text is wider than half of
/// a small phone.
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, maxLines: 1, softWrap: false),
      );
}
