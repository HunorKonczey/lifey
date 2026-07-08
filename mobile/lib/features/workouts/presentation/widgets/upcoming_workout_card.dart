import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../trainer_invite/application/trainer_invite_controller.dart';
import '../../application/workout_session_controller.dart';
import '../../domain/workout_session.dart';
import '../log_session_screen.dart';

const _dismissedOnKey = 'lifey.upcomingWorkoutCardDismissedOn';

bool _isToday(DateTime dateTime) {
  final now = DateTime.now();
  final d = dateTime.toLocal();
  return d.year == now.year && d.month == now.month && d.day == now.day;
}

String _todayKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

/// Floating pop-up card for a workout the trainer scheduled for *today*,
/// shown above the bottom nav on app launch/foreground — mirrors
/// `TrainerInviteCard`'s look and mounting point, but reads from the local
/// sync cache instead of polling (docs/personal_trainer/10-utemezett-edzesek-web-mobil.md
/// §3). Only ever shows the day's first (by scheduled time) upcoming
/// session; dismissal persists for the rest of the day, unlike the invite
/// card's per-app-session-only dismissal, since this one is meant to
/// reappear daily.
///
/// If a trainer invite is pending on this open, the invite wins for the
/// whole of this open — this card stays suppressed even if the invite is
/// responded to before backgrounding, and only becomes eligible again on the
/// next launch/foreground ("a következő megnyitáskor jön").
class UpcomingWorkoutCard extends ConsumerStatefulWidget {
  const UpcomingWorkoutCard({super.key});

  @override
  ConsumerState<UpcomingWorkoutCard> createState() => _UpcomingWorkoutCardState();
}

class _UpcomingWorkoutCardState extends ConsumerState<UpcomingWorkoutCard>
    with WidgetsBindingObserver {
  String? _dismissedOn; // yyyy-MM-dd, null until prefs are read (or never dismissed)
  bool _prefsLoaded = false;

  /// Sticky for the current open/foreground stretch — set as soon as a
  /// pending invite is observed, and only cleared on the next resume.
  bool _suppressedByInviteThisOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDismissed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => _suppressedByInviteThisOpen = false);
    }
  }

  Future<void> _loadDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _dismissedOn = prefs.getString(_dismissedOnKey);
      _prefsLoaded = true;
    });
  }

  Future<void> _dismiss() async {
    final todayKey = _todayKey();
    setState(() => _dismissedOn = todayKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedOnKey, todayKey);
  }

  void _start(WorkoutSession session) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => LogSessionScreen(session: session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wait for the invite provider's first resolution before ever showing
    // this card, so a pending invite that hasn't loaded yet can't lose the
    // race and let this card flash on screen first.
    final inviteState = ref.watch(trainerInviteControllerProvider);
    final hasPendingInviteNow = (inviteState.value ?? const []).isNotEmpty;
    if (hasPendingInviteNow && !_suppressedByInviteThisOpen) {
      // Deferred to a post-frame callback: this runs during build (a watch
      // can fire mid-build), and setState can't be called synchronously here.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _suppressedByInviteThisOpen = true);
      });
    }

    final sessions = ref.watch(workoutSessionControllerProvider).value ?? const [];
    final todaysSessions = sessions.where((s) => s.isUpcoming && _isToday(s.scheduledFor!)).toList()
      ..sort((a, b) => (a.scheduledTime ?? '99:99').compareTo(b.scheduledTime ?? '99:99'));

    final dismissedToday = _dismissedOn == _todayKey();
    final blockedByInvite =
        inviteState.isLoading || hasPendingInviteNow || _suppressedByInviteThisOpen;
    final current = !_prefsLoaded || blockedByInvite || dismissedToday || todaysSessions.isEmpty
        ? null
        : todaysSessions.first;

    return IgnorePointer(
      ignoring: current == null,
      child: AnimatedSlide(
        offset: current == null ? const Offset(0, 0.3) : Offset.zero,
        duration: AppDuration.slow,
        curve: AppCurve.collapse,
        child: AnimatedOpacity(
          opacity: current == null ? 0.0 : 1.0,
          duration: AppDuration.base,
          curve: AppCurve.standard,
          child: current == null
              ? const SizedBox.shrink()
              : _CardContent(
                  key: ValueKey(current.clientId),
                  session: current,
                  moreCount: todaysSessions.length - 1,
                  onDismiss: _dismiss,
                  onStart: () => _start(current),
                ),
        ),
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent({
    super.key,
    required this.session,
    required this.moreCount,
    required this.onDismiss,
    required this.onStart,
  });

  final WorkoutSession session;
  final int moreCount;
  final VoidCallback onDismiss;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final name = session.templateName ?? l10n.freeWorkoutLabel;
    final title = session.scheduledTime != null
        ? l10n.upcomingWorkoutCardTitleWithTime(session.scheduledTime!, name)
        : l10n.upcomingWorkoutCardTitle(name);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Dismissible(
        key: ValueKey('dismiss-${session.clientId}'),
        direction: DismissDirection.horizontal,
        onDismissed: (_) => onDismiss(),
        child: ClipRRect(
          borderRadius: AppRadius.lgAll,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
                borderRadius: AppRadius.lgAll,
                border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: scheme.tertiaryContainer,
                        child: Icon(Icons.fitness_center, color: scheme.onTertiaryContainer),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: Theme.of(context).textTheme.titleSmall),
                            if (moreCount > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                l10n.upcomingWorkoutMoreCount(moreCount),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: onDismiss,
                        tooltip: l10n.upcomingWorkoutDismissTooltip,
                        icon: const Icon(Icons.close, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: onDismiss,
                        child: Text(l10n.laterButtonLabel),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: onStart,
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                        ),
                        child: Text(l10n.startWorkoutButtonLabel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
