import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/format/cardio_formatter.dart';
import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_type.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/lifey_card.dart';
import '../../../../shared/widgets/ds/list_group.dart';
import '../../../../shared/widgets/ds/tinted_chip.dart';
import '../../../settings/domain/user_settings.dart';
import '../../domain/chat_card.dart';

/// The words of a result card, formatted for the *reader*: the kind label, the
/// title and the one-line summary. The card draws from these, and the thread's
/// screen-reader label is built from the same text, so what is seen and what is
/// spoken cannot drift (docs/chat/83-chat-result-card-plan.md §7 "Locale").
class ChatCardText {
  ChatCardText._(this.kind, this.title, this.summary);

  /// "Workout" / "Cardio" / "Personal record" — the overline.
  final String kind;
  final String title;

  /// The numbers on one line ("56 min · 8,450 kg volume · 6 exercises"); null
  /// when the card carries none, so nothing is drawn rather than a zero.
  final String? summary;

  factory ChatCardText.of(
    BuildContext context,
    ChatCard card, {
    UnitSystem unitSystem = UnitSystem.metric,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final fmt = LifeyFormat.of(context);
    return switch (card) {
      WorkoutChatCard() => _workout(l10n, fmt, card, unitSystem),
      PrChatCard() => ChatCardText._(
          l10n.chatCardRecordLabel,
          card.exerciseName,
          '${_prValue(l10n, card)} · ${_prKind(l10n, card)}',
        ),
      UnknownChatCard() => ChatCardText._(l10n.chatCardUnsupported, l10n.chatCardUnsupported, null),
    };
  }

  static ChatCardText _workout(
    AppLocalizations l10n,
    LifeyFormat fmt,
    WorkoutChatCard card,
    UnitSystem unitSystem,
  ) {
    final title = (card.title ?? '').trim();
    final parts = <String>[];
    final seconds = card.durationSeconds;
    if (seconds != null && seconds > 0) {
      parts.add(card.isCardio
          ? CardioFormatter.duration(Duration(seconds: seconds))
          : l10n.workoutDurationMin((seconds / 60).round().clamp(1, 1 << 20)));
    }
    final distance = card.distanceMeters;
    if (card.isCardio && distance != null && distance > 0) {
      parts.add(CardioFormatter.distance(distance, unitSystem));
    }
    final volume = card.volumeKg;
    if (!card.isCardio && volume != null && volume > 0) {
      parts.add(l10n.workoutDoneVolume(fmt.integer(volume)));
    }
    final exercises = card.exerciseCount;
    if (!card.isCardio && exercises != null && exercises > 0) {
      parts.add(l10n.chatCardExercises(exercises));
    }
    return ChatCardText._(
      card.isCardio ? l10n.chatCardCardioLabel : l10n.chatCardWorkoutLabel,
      title.isNotEmpty
          ? title
          : (card.isCardio ? l10n.chatCardUntitledCardio : l10n.chatCardUntitledWorkout),
      parts.isEmpty ? null : parts.join(' · '),
    );
  }

  /// "102.5 kg" or "8 reps" — the number a record is about.
  static String _prValue(AppLocalizations l10n, PrChatCard card) {
    final isReps = card.prKind == ChatPrKind.repsAtWeight;
    return isReps
        ? '${card.value.round()} ${l10n.workoutSuccessRepsAbbrev}'
        : '${_kg(l10n, card.value)} ${l10n.statUnitKg}';
  }

  static String _prKind(AppLocalizations l10n, PrChatCard card) => switch (card.prKind) {
        ChatPrKind.maxWeight => l10n.workoutDonePrKindHeaviest,
        ChatPrKind.estimatedOneRm => l10n.workoutDonePrKindOneRm,
        ChatPrKind.repsAtWeight => l10n.workoutDonePrKindReps(_kg(l10n, card.weightKg ?? 0)),
      };

  static String _kg(AppLocalizations l10n, double value) =>
      NumberFormat('0.#', l10n.localeName).format(double.parse(value.toStringAsFixed(1)));
}

/// A shared workout or personal record, drawn as a card of its own in the
/// thread (docs/chat/83-chat-result-card-plan.md §4).
///
/// It *replaces* the text bubble rather than sitting inside one — a card inside
/// a bubble would be the nested box the design system forbids, and the olive
/// own-side bubble would put every number on a tint the metric colours were
/// never contrast-checked against. Own messages keep a primary hairline so the
/// sides still read.
///
/// Static unless [onTap] is given; the chevron appears exactly when it is.
class ChatCardView extends StatelessWidget {
  const ChatCardView({
    super.key,
    required this.card,
    required this.isOwn,
    this.caption,
    this.unitSystem = UnitSystem.metric,
    this.onTap,
    this.onLongPress,
  });

  final ChatCard card;
  final bool isOwn;

  /// The message's body, when the sender added a note.
  final String? caption;
  final UnitSystem unitSystem;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;
    final mc = context.metricColors;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final text = ChatCardText.of(context, card, unitSystem: unitSystem);
    final unknown = card is UnknownChatCard;

    final (IconData icon, Color color) = switch (card) {
      WorkoutChatCard(isCardio: true) => (Icons.directions_run_rounded, mc.heart),
      WorkoutChatCard() => (Icons.fitness_center_rounded, scheme.primary),
      PrChatCard() => (Icons.emoji_events_rounded, mc.record),
      UnknownChatCard() => (Icons.help_outline_rounded, p.text2),
    };

    final note = (caption ?? '').trim();
    final tappable = onTap != null;

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: isOwn
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.55)),
            )
          : null,
      child: LifeyCard(
        padding: const EdgeInsets.all(AppSpacing.s16),
        onTap: onTap,
        onLongPress: onLongPress,
        semanticsLabel: tappable ? l10n.chatCardOpenHint : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ListIconHolder(icon: icon, color: color, size: 36),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(
                    unknown ? text.kind : text.kind.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.labelSmall!.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: unknown ? p.text : p.text2,
                    ),
                  ),
                ),
                if (tappable) Icon(Icons.chevron_right_rounded, size: 22, color: p.text3),
              ],
            ),
            if (!unknown) ...[
              const SizedBox(height: AppSpacing.s12),
              Text(
                text.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: p.text),
              ),
              ..._numbers(context, l10n, t, p, mc, text),
            ],
            if (note.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s12),
              Text(note, style: t.bodyMedium!.copyWith(color: p.text)),
            ],
            if (!unknown) ...[
              const SizedBox(height: AppSpacing.s12),
              Text(
                LifeyFormat.of(context).shortDate(card.occurredAt),
                style: t.bodySmall!.copyWith(color: p.text3),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _numbers(
    BuildContext context,
    AppLocalizations l10n,
    TextTheme t,
    AppPalette p,
    AppMetricColors mc,
    ChatCardText text,
  ) {
    final c = card;
    if (c is PrChatCard) {
      final delta = c.delta;
      final isReps = c.prKind == ChatPrKind.repsAtWeight;
      final unit = isReps ? l10n.workoutSuccessRepsAbbrev : l10n.statUnitKg;
      return [
        const SizedBox(height: AppSpacing.s8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                ChatCardText._prValue(l10n, c),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.number(30, color: p.text),
              ),
            ),
            if (delta != null && delta > 0) ...[
              const SizedBox(width: AppSpacing.s8),
              Text(
                '+${isReps ? delta.round().toString() : ChatCardText._kg(l10n, delta)} $unit',
                style: AppType.number(14, weight: FontWeight.w700, color: mc.improvement),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(ChatCardText._prKind(l10n, c), style: t.bodyMedium!.copyWith(color: p.text2)),
      ];
    }
    if (c is WorkoutChatCard) {
      final records = c.recordCount ?? 0;
      return [
        if (text.summary != null) ...[
          const SizedBox(height: AppSpacing.s4),
          Text(text.summary!, style: t.bodyMedium!.copyWith(color: p.text2)),
        ],
        if (records > 0) ...[
          const SizedBox(height: AppSpacing.s12),
          TintedChip(
            icon: Icons.emoji_events_rounded,
            color: mc.record,
            label: l10n.chatCardRecordsChip(records),
          ),
        ],
      ];
    }
    return const [];
  }
}
