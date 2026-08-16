import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_permission_preferences.dart';
import '../../../core/location/location_service_geolocator.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/quick_start_options_provider.dart';
import '../application/workout_session_controller.dart';
import '../domain/activity_type.dart';
import '../domain/workout_session.dart';
import '../domain/workout_template.dart';
import 'activity_picker_screen.dart';
import 'log_session_screen.dart';
import 'open_workout_screens.dart';
import 'widgets/gps_explainer_sheet.dart';

/// Opens the quick-start sheet — the FAB long-press destination
/// (docs/cardio/59-cardio-implementation-plan.md C2.7, M01/M02).
/// [useRootNavigator] matches `LogCardioSheet`/`AddExerciseSheet`'s existing
/// convention so the sheet sits above the bottom nav, not clipped by the
/// Workouts tab's own navigator.
Future<void> showQuickStartSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const QuickStartSheet(),
  );
}

/// Four highest-ranked entries ([quickStartEntriesProvider]) as large tiles,
/// plus a way into the full picker — M01 (warm) and M02 (cold start) are
/// the same widget tree, the only difference is [isQuickStartColdStartProvider]
/// gating the explainer banner.
///
/// **One tap starts the workout immediately** — no intermediate setup
/// screen (the plan's kész-ha, `59-cardio-implementation-plan.md` C2.7):
/// tapping a tile pushes straight into the live [CardioSessionScreen] or
/// [LogSessionScreen], exactly as if the user had gone through the slower,
/// pre-existing FAB-tap → `TemplatePickerScreen` → `LogSessionScreen` path,
/// just skipping the browsing step.
class QuickStartSheet extends ConsumerWidget {
  const QuickStartSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final entries = ref.watch(quickStartEntriesProvider).take(4).toList();
    final coldStart = ref.watch(isQuickStartColdStartProvider);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s4,
          AppSpacing.s16,
          AppSpacing.s24,
        ),
        // Scrollable, not just `mainAxisSize: min`: on a short viewport (a
        // small phone in landscape, or a cold-start banner pushing the grid
        // down) the title + subtitle + optional banner + 2×2 grid + "All
        // workout types" row can exceed the available sheet height —
        // `showModalBottomSheet(isScrollControlled: true)` doesn't shrink
        // its content to fit on its own, same reasoning as
        // `LogCardioSheet`'s body.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // M01's title line carries the *why* of the order on its
              // right — without it the four tiles look arbitrary.
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      l10n.quickStartSheetTitle,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  Text(
                    l10n.quickStartOrderHint,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.quickStartSheetSubtitle,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              if (coldStart) ...[
                const SizedBox(height: AppSpacing.s12),
                _ColdStartBanner(text: l10n.quickStartColdStartBanner),
              ],
              const SizedBox(height: AppSpacing.s16),
              // M01's grid is 2×2 of fixed-height (142) tiles, not
              // aspect-ratio driven: the chip, title and subtitle have to
              // land in the same place on every tile regardless of how wide
              // the phone is.
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.s12,
                mainAxisSpacing: AppSpacing.s12,
                mainAxisExtent: 142,
                children: [for (final resolved in entries) _QuickStartTile(resolved: resolved)],
              ),
              const SizedBox(height: AppSpacing.s12),
              _AllActivityTypesRow(label: l10n.allActivityTypesLabel),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColdStartBanner extends StatelessWidget {
  const _ColdStartBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.34)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _AllActivityTypesRow extends StatelessWidget {
  const _AllActivityTypesRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.input),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(builder: (_) => const ActivityPickerScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: 15),
          child: Row(
            children: [
              Icon(Icons.apps, size: 22, color: scheme.primary),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700))),
              Icon(Icons.chevron_right, size: 20, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// One quick-start tile — the actual "start the workout" logic lives here
/// so [ActivityPickerScreen]'s rows (same underlying actions, different
/// list shape) can call the same two entry points, [startCardioQuickly] and
/// [startStrengthQuickly].
class _QuickStartTile extends ConsumerWidget {
  const _QuickStartTile({required this.resolved});

  final ResolvedQuickStartEntry resolved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final entry = resolved.entry;

    final IconData icon;
    final Color color;
    final String title = quickStartEntryTitle(l10n, resolved);
    final String subtitle;
    if (entry.isCardio) {
      final type = entry.activityType!;
      icon = activityTypeIcon(type);
      color = activityTypeColor(type, context);
      subtitle = activityModalitySubtitle(l10n, activityFamilyOf(type));
    } else {
      icon = activityTypeIcon('STRENGTH');
      color = activityTypeColor('STRENGTH', context);
      final template = resolved.template;
      subtitle = template != null
          ? l10n.exercisesCountLabel(template.exercises.length)
          : l10n.emptyWorkoutSubtitle;
    }

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => entry.isCardio
            ? startCardioQuickly(context, ref, entry.activityType!)
            : startStrengthQuickly(context, template: resolved.template),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // M01 sizes the chip at 56 here — the tile is a thumb target
              // first and a label second.
              Container(
                width: 56,
                height: 56,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.16)),
                child: Icon(icon, size: 30, color: color),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// docs/cardio/59-cardio-implementation-plan.md C2.7 simplification: a
/// single per-family hint ("Distance · pace · GPS" / "Cadence · power" /
/// "Playing time · heart-rate zones") rather than the seven per-type
/// strings the M01/M02/M03 mockups each show slightly differently (e.g.
/// hiking's own elevation-focused text) — one mechanism, reused by both the
/// quick-start tiles and the full activity picker.
String activityModalitySubtitle(AppLocalizations l10n, ActivityFamily family) {
  return switch (family) {
    ActivityFamily.distance => l10n.distanceModalitySubtitle,
    ActivityFamily.machine => l10n.machineModalitySubtitle,
    ActivityFamily.game => l10n.gameModalitySubtitle,
  };
}

/// Creates+persists a new cardio session for [activityType] — pure data
/// work, no navigation. Builds the navigation [WorkoutSession] locally
/// rather than waiting for [workoutSessionControllerProvider]'s stream to
/// emit the freshly-created row: the repository already knows
/// `startedAt`/`movingSinceEpochMs` are the same value and `movingSeconds`
/// starts at 0 (see `WorkoutSessionController.startCardioSession`), so
/// there's nothing to wait for — this mirrors exactly what gets persisted,
/// without a stream-lookup race.
///
/// Split out of [startCardioQuickly] so `workout_resume_prompt.dart`'s
/// C2.11a deep-link/app-shortcut/widget entry point can reuse the exact same
/// creation logic without a [BuildContext] or a sheet to pop.
Future<WorkoutSession> createCardioSession(
    WorkoutSessionController controller, String activityType) async {
  final startedAt = DateTime.now();
  final clientId = await controller.startCardioSession(
    startedAt: startedAt,
    activityType: activityType,
  );
  return WorkoutSession(
    clientId: clientId,
    exercises: const [],
    sets: const [],
    startedAt: startedAt,
    sessionKind: 'CARDIO',
    activityType: activityType,
    movingSeconds: 0,
    movingSinceEpochMs: startedAt.millisecondsSinceEpoch,
  );
}

/// Starts a cardio session for [activityType] and pushes straight into the
/// live [CardioSessionScreen] — the C2.7 entry point `open_workout_screens.dart`'s
/// own doc comment already anticipated ("today only reachable from tests,
/// since the quick-start entry point is C2.7").
///
/// For a DISTANCE-family activity, the very first call ever additionally
/// shows [GpsExplainerSheet] before the system location dialog
/// (docs/cardio/54-cardio-gps-route-plan.md §3.1, C4a.2, M26) — never again
/// after that, and never blocking the session from starting either way
/// (D-C.5). Only this quick-start-sheet/full-picker path gates the
/// explainer; `workout_resume_prompt.dart`'s C2.11a deep-link/app-shortcut/
/// widget entry point calls [createCardioSession] directly and skips it, on
/// purpose — a widget/shortcut tap promises "one gesture starts the
/// workout" (C2.11a's own kész-ha), which an interactive sheet would break.
/// A session started that way before the explainer has ever been seen just
/// starts without GPS, exactly like the "Indítás GPS nélkül" choice would —
/// the in-session status card (`CardioSessionScreen`, M27/M28) still offers
/// "Allow" from there.
Future<void> startCardioQuickly(BuildContext context, WidgetRef ref, String activityType) async {
  HapticFeedback.mediumImpact();
  final sheetNavigator = Navigator.of(context);
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  // Captured up front: `ref` reads the *provider value* here (not a live
  // reference into the tile's own widget), so these stay valid after
  // `sheetNavigator.pop()` disposes the tile below — `ref` itself does not.
  // Using `ref.read(...)` again after that pop throws ("Using 'ref' when a
  // widget is about to or has been unmounted is unsafe"), caught the hard
  // way via this function's own widget tests.
  final sessionController = ref.read(workoutSessionControllerProvider.notifier);

  if (activityFamilyOf(activityType) == ActivityFamily.distance) {
    final prefs = ref.read(locationPermissionPreferencesProvider);
    if (!await prefs.hasSeenGpsExplainer()) {
      final locationService = ref.read(locationServiceProvider);
      // Marked seen up front, before the sheet even resolves — the doc's own
      // design note is explicit that this shows exactly once ever, so an
      // ignored/swiped-away sheet must count as "seen" too, same as either
      // real button (see GpsExplainerChoice's doc).
      await prefs.setSeenGpsExplainer();
      sheetNavigator.pop();
      if (!rootNavigator.mounted) return;
      final choice = await showGpsExplainerSheet(rootNavigator.context);
      if (choice == GpsExplainerChoice.requestPermission) {
        await locationService.requestPermission();
      }
      final session = await createCardioSession(sessionController, activityType);
      await openSessionScreen(rootNavigator, session);
      return;
    }
  }

  final session = await createCardioSession(sessionController, activityType);
  sheetNavigator.pop();
  await openSessionScreen(rootNavigator, session);
}

/// Starts a strength session from [template] (`null` = freeform "Empty
/// workout") and pushes straight into [LogSessionScreen] — same shape as
/// `TemplatePickerScreen._start`, deliberately **not** routed through
/// `openSessionScreen` (its own doc comment excludes fresh template starts
/// on purpose: there's no existing session to branch on yet).
void startStrengthQuickly(BuildContext context, {required WorkoutTemplate? template}) {
  HapticFeedback.mediumImpact();
  final sheetNavigator = Navigator.of(context);
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  sheetNavigator.pop();
  rootNavigator.push(MaterialPageRoute(builder: (_) => LogSessionScreen(template: template)));
}
