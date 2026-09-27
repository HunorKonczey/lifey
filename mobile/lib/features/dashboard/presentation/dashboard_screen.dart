import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ads/banner_ad_slot.dart';
import '../../../core/ads/nav_reserved_space.dart';
import '../../../core/sync/pull_engine.dart';
import '../../../core/sync/sync_engine_provider.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/format/lifey_format.dart';
import '../../../shared/widgets/ds/lifey_header.dart';
import '../../auth/application/auth_controller.dart';
import '../../../shared/widgets/nav_collapse_controller.dart';
import '../../chat/application/conversation_list_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/user_settings.dart';
import '../../water/presentation/widgets/add_water_sheet.dart';
import '../../weight/application/weight_controller.dart';
import '../../weight/domain/weight_entry.dart';
import '../../workouts/application/recommended_template_provider.dart';
import '../../workouts/application/workout_session_controller.dart';
import '../../workouts/domain/workout_template.dart';
import '../../workouts/presentation/log_session_screen.dart';
import '../../workouts/presentation/open_workout_screens.dart';
import '../../workouts/presentation/widgets/post_workout_feedback_sheet.dart';
import '../../workouts/presentation/widgets/recommended_workout_card.dart';
import '../../nutrition/presentation/log_meal_screen.dart';
import '../../nutrition/presentation/nutrition_screen.dart';
import '../../onboarding/presentation/widgets/onboarding_banner.dart';
import '../../streaks/application/streaks_provider.dart';
import '../../streaks/domain/streak.dart';
import '../../streaks/presentation/widgets/recap_ready_card.dart';
import '../../streaks/presentation/widgets/streak_chip_row.dart';
import '../application/dashboard_controller.dart';
import '../application/today_steps_controller.dart';
import '../domain/dashboard_data.dart';
import '../domain/recent_workout.dart';
import 'widgets/calorie_hero_card.dart';
import 'widgets/dashboard_avatar_menu.dart';
import 'widgets/dashboard_tiles.dart';
import 'widgets/recent_workouts_section.dart';
import 'widgets/today_meals_section.dart';
import 'widgets/weekly_calories_card.dart';
import 'widgets/sponsorship_ended_card.dart';

/// Opens the matching session straight into edit mode, falling back to the
/// "Workouts" tab if the session isn't in the local cache (e.g. mid-sync).
Future<void> _openWorkout(BuildContext context, WidgetRef ref, String clientId) async {
  final sessions = ref.read(workoutSessionControllerProvider).value ?? const [];
  final session = sessions.where((s) => s.clientId == clientId).firstOrNull;
  if (session == null) {
    context.go('/workouts');
    return;
  }
  await openSessionScreen(Navigator.of(context), session);
}

Future<void> _startRecommendedWorkout(BuildContext context, WorkoutTemplate template) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => LogSessionScreen(template: template)),
  );
}

/// "Rate this workout" nudge chip handler — opens the feedback sheet
/// directly from the dashboard tile, without navigating into the full
/// session screen. See [RecentWorkout.needsRatingNudge].
Future<void> _rateWorkout(BuildContext context, WidgetRef ref, String clientId) async {
  final result = await showPostWorkoutFeedbackSheet(context);
  if (result == null) return;
  await ref.read(workoutSessionControllerProvider.notifier).rateSession(
        clientId,
        rpe: result.rpe,
        feedbackNote: result.feedbackNote,
      );
}

/// Dashboard: today's calories & macros, current weight, recent workouts.
/// Fully local-first — works offline, and updates the instant a write lands
/// in any of the underlying feature repositories (see
/// `dashboardControllerProvider`), so unlike before, no manual refresh is
/// needed to see a just-logged meal/weight/workout/water entry show up.
///
/// The underlying cache is normally kept fresh by [ConnectivitySyncController]
/// (connectivity restore / app resume / a 60s foreground timer), but that
/// controller runs independently of whether the dashboard is on screen and
/// swallows failures silently. So this screen also forces its own sync+pull
/// every time it becomes visible (first build, and app resume while it's the
/// active screen) — e.g. the tab was left open overnight and is checked the
/// next morning — instead of trusting only the background triggers.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_forceSync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_forceSync());
    }
  }

  /// Also used by pull-to-refresh: "sync now" (push then pull) rather than
  /// re-fetching this screen's own data, since that's already live —
  /// useful for forcing a sync attempt without waiting for the next
  /// automatic trigger.
  Future<void> _forceSync() async {
    try {
      await ref.read(syncEngineProvider).sync();
      await ref.read(pullEngineProvider).pullAll();
    } catch (_) {
      // Best-effort, same as the automatic triggers — no connectivity or a
      // backend error just means try again later.
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(dashboardControllerProvider);
    final settings = ref.watch(settingsControllerProvider).value ?? const UserSettings.defaults();
    final weights = ref.watch(weightControllerProvider).value ?? const <WeightEntry>[];
    final todaySteps = ref.watch(todayStepsControllerProvider).value;
    final recommendedTemplate = ref.watch(recommendedTemplateProvider);
    final streaks = ref.watch(streaksProvider);

    // The pinned header collapses to the status bar + a 52 px row; the
    // pull-to-refresh spinner starts below it.
    final headerBottom = MediaQuery.paddingOf(context).top + 52;

    return Scaffold(
      body: ScrollCollapseListener(
        child: Stack(
          children: [
            Positioned.fill(
              child: RefreshIndicator(
                edgeOffset: headerBottom,
                onRefresh: _forceSync,
                child: _DashboardBody(
                  data: data,
                  settings: settings,
                  weights: weights,
                  todaySteps: todaySteps,
                  recommendedTemplate: recommendedTemplate,
                  streaks: streaks,
                  onStartRecommended: (template) =>
                      _startRecommendedWorkout(context, template),
                  onWorkoutTap: (clientId) => _openWorkout(context, ref, clientId),
                  onRateWorkoutTap: (clientId) => _rateWorkout(context, ref, clientId),
                  onMealsTap: () {
                    ref.read(nutritionPendingTabProvider.notifier).set(0);
                    context.go('/nutrition');
                  },
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: bannerBottom(MediaQuery.paddingOf(context).bottom),
              child: const BannerAdSlot(tabIndex: 0),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({
    required this.data,
    required this.settings,
    required this.onWorkoutTap,
    required this.onRateWorkoutTap,
    required this.onMealsTap,
    required this.onStartRecommended,
    this.weights = const [],
    this.todaySteps,
    this.recommendedTemplate,
    this.streaks = const [],
  });

  final DashboardData data;
  final UserSettings settings;
  /// Newest first.
  final List<WeightEntry> weights;
  final int? todaySteps;
  final WorkoutTemplate? recommendedTemplate;
  final List<Streak> streaks;
  final ValueChanged<String> onWorkoutTap;
  final ValueChanged<String> onRateWorkoutTap;
  final VoidCallback onMealsTap;
  final ValueChanged<WorkoutTemplate> onStartRecommended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = data.stats;
    final l10n = AppLocalizations.of(context)!;

    final bannerHeight = ref.watch(bannerAdSlotHeightProvider(0));
    // The body extends behind the bottom nav, so the safe-area bottom already
    // includes the nav's height.
    final bottomPad = MediaQuery.paddingOf(context).bottom + bannerHeight + AppSpacing.s56;

    final format = LifeyFormat.of(context);
    final user = ref.watch(authControllerProvider).value;
    final firstName = user?.firstName?.trim();

    final children = <Widget>[
        // ── Streak strip — right under the header ────────────────────────
        if (streaks.isNotEmpty) ...[
          StreakChipRow(streaks: streaks, onTap: () => context.push('/recap')),
          const SizedBox(height: 16),
        ],

        // ── Recommended workout — pinned above everything, styled distinct
        // from the plain cards below so it doesn't read as a list item ─────
        if (recommendedTemplate != null) ...[
          RecommendedWorkoutCard(
            template: recommendedTemplate!,
            onTap: () => onStartRecommended(recommendedTemplate!),
          ),
        ],

        // ── Onboarding banner (hidden once onboarded or dismissed) ─────────
        const OnboardingBanner(),

        // ── "Your coach's Pro has ended" — shown once, then never again
        // (`69` §12.1). Above the fold on purpose: it explains why features
        // the user had yesterday are gone today. ─────────────────────────
        const SponsorshipEndedCard(),

        // ── Calories + macros — the one hero of the screen ────────────
        CalorieHeroCard(
          stats: stats,
          settings: settings,
          onTap: () => context.go('/nutrition'),
        ),
        const SizedBox(height: 16),

        // ── Water + steps + weight tiles ──────────────────────────────
        DashboardTiles(
          stats: stats,
          settings: settings,
          todaySteps: todaySteps,
          weights: weights,
          onAddWater: () => showAddWaterSheet(context),
          onWeightTap: () => context.go('/weight'),
        ),
        const SizedBox(height: 16),

        // ── This week — calories bar chart ──────────────────────────────────────────────────────────────
        WeeklyCaloriesCard(points: data.weeklyCalories, goal: settings.dailyCalorieGoal),

        // No gaps around the section labels below: a label row is 48 dp tall
        // (its "See all" is a 48 dp target), which already puts the label's
        // text 16 dp below the previous card and 24 dp above the next one —
        // the canvas' rhythm.

        // ── Weekly recap ready nudge (hidden most of the time) ─────────
        const RecapReadyCard(),

        // ── Today's meals ─────────────────────────────────────────────
        TodayMealsSection(
          groups: data.todaysMealGroups,
          onSeeAll: onMealsTap,
          onMealTap: onMealsTap,
          onAddMeal: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const LogMealScreen()),
          ),
          onPhoto: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const LogMealScreen(startWithPhoto: true)),
          ),
        ),

        // ── Recent workouts ───────────────────────────────────────────
        RecentWorkoutsSection(
          workouts: data.recentWorkouts,
          unitSystem: settings.unitSystem,
          onSeeAll: () => context.go('/workouts'),
          onTap: onWorkoutTap,
          onRate: onRateWorkoutTap,
        ),
    ];

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        LifeyHeader(
          overline: format.dayLabel(DateTime.now()),
          title: _greeting(l10n, firstName),
          // The scrolled row is just the screen's name, as on the canvas.
          collapsedTitle: l10n.dashboardTabLabel,
          actions: [
            // Chat's only permanent entry point: it gets no bottom-nav
            // branch of its own (docs/chat/40-trainer-chat-plan.md §6.1), so
            // the unread dot lives here for both roles.
            HeaderIconButton(
              icon: Icons.chat_bubble_outline_rounded,
              tooltip: l10n.chatOpenTooltip,
              showDot: (ref.watch(unreadBadgeProvider).value ?? 0) > 0,
              onPressed: () => context.push('/chat'),
            ),
            const DashboardAvatarMenu(),
          ],
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s16, AppSpacing.s20, bottomPad),
          sliver: SliverList(delegate: SliverChildListDelegate(children)),
        ),
      ],
    );
  }

  /// "Good morning, Anna" — by time of day; the plain greeting when the
  /// account has no first name.
  String _greeting(AppLocalizations l10n, String? firstName) {
    final hour = DateTime.now().hour;
    final hasName = firstName != null && firstName.isNotEmpty;
    if (hour >= 5 && hour < 12) {
      return hasName ? l10n.greetingMorningName(firstName) : l10n.greetingMorning;
    }
    if (hour >= 12 && hour < 18) {
      return hasName ? l10n.greetingAfternoonName(firstName) : l10n.greetingAfternoon;
    }
    return hasName ? l10n.greetingEveningName(firstName) : l10n.greetingEvening;
  }
}
