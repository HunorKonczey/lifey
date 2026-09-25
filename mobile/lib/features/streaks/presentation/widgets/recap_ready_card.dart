import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/notice_card.dart';
import '../../application/weekly_recap_provider.dart';
import '../../data/recap_preferences.dart';
import '../../domain/weekly_recap.dart';

/// Dismissible dashboard card nudging toward the just-completed week's
/// recap — shown only early in the new week (Monday–Wednesday, so the nudge
/// doesn't linger stale all week), only when that week actually has
/// something to show, and only until dismissed or the recap screen itself
/// has been opened (see [RecapPreferences]).
///
/// Same shape as `OnboardingBanner`: a stateful prefs load gated by
/// `_prefsLoaded` to avoid a first-frame flash of the card before the
/// dismissal state is known.
class RecapReadyCard extends ConsumerStatefulWidget {
  const RecapReadyCard({super.key, this.now});

  /// Overrides "today" for tests; production call sites leave this null and
  /// get [DateTime.now].
  final DateTime? now;

  @override
  ConsumerState<RecapReadyCard> createState() => _RecapReadyCardState();
}

class _RecapReadyCardState extends ConsumerState<RecapReadyCard> {
  bool _prefsLoaded = false;
  DateTime? _lastSeenWeekStart;

  @override
  void initState() {
    super.initState();
    _loadLastSeen();
  }

  Future<void> _loadLastSeen() async {
    final lastSeen = await ref.read(recapPreferencesProvider).lastSeenRecapWeekStart();
    if (!mounted) return;
    setState(() {
      _lastSeenWeekStart = lastSeen;
      _prefsLoaded = true;
    });
  }

  Future<void> _dismiss(DateTime weekStart) async {
    setState(() => _lastSeenWeekStart = weekStart);
    await ref.read(recapPreferencesProvider).markRecapSeen(weekStart);
  }

  @override
  Widget build(BuildContext context) {
    if (!_prefsLoaded) return const SizedBox.shrink();

    // Only during the first half of the new week — a card still nudging
    // toward "last week's recap" on a Saturday reads stale.
    final today = widget.now ?? DateTime.now();
    if (today.weekday > DateTime.wednesday) return const SizedBox.shrink();

    final weekStart = WeeklyRecap.lastCompletedWeekStart(today);
    if (_lastSeenWeekStart == weekStart) return const SizedBox.shrink();

    final recap = ref.watch(weeklyRecapProvider(weekStart));
    if (!recap.hasAnyData) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: NoticeCard(
        icon: Icons.auto_awesome_rounded,
        title: l10n.recapReadyCardTitle,
        actionLabel: l10n.recapReadyCardCta,
        onAction: () => context.push('/recap'),
        onDismiss: () => _dismiss(weekStart),
        dismissTooltip: l10n.recapReadyCardDismissTooltip,
      ),
    );
  }
}
