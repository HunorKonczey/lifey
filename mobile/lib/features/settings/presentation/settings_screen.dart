import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/entitlements/entitlement.dart';
import '../../../core/entitlements/entitlement_providers.dart';
import '../../../core/network/error_message.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/sync/logout_preflight.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/watch/watch_workout_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/ds/gallery/design_gallery_screen.dart';
import '../../../shared/widgets/ds/lifey_header.dart';
import '../../../shared/widgets/ds/lifey_sheet.dart';
import '../../../shared/widgets/ds/list_group.dart';
import '../../../shared/widgets/ds/section_label.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/nav_collapse_controller.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/change_password_screen.dart';
import '../../onboarding/presentation/onboarding_edit_screen.dart';
import '../../water/presentation/water_sources_screen.dart';
import '../application/avatar_controller.dart';
import '../application/settings_controller.dart';
import '../domain/user_settings.dart';
import 'notification_settings_screen.dart';
import 'widgets/logout_dialog.dart';
import 'widgets/settings_goals.dart';
import 'widgets/settings_integrations.dart';
import 'widgets/settings_kit.dart';
import 'widgets/settings_my_trainers.dart';
import 'widgets/settings_profile_card.dart';
import 'widgets/subscription_tile.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Form state (initialized on first data load)
  bool _initialized = false;
  late UnitSystem _unitSystem;
  late ThemePreference _theme;
  late LanguagePreference _language;
  int? _calorieGoal;
  int? _proteinGoal;
  int? _carbsGoal;
  int? _fatGoal;
  double? _waterGoal;
  int? _stepGoal;
  bool _avatarBusy = false;

  // Passed through unchanged on every autosave from this screen (not edited
  // here) so a save doesn't silently reset fields owned by other screens
  // (notification settings) back to their class defaults.
  late bool _workoutReminderEnabled;
  late bool _trainerCommentPushEnabled;
  late bool _trainerGoalsPushEnabled;
  late bool _programAssignedPushEnabled;
  late bool _chatPushEnabled;

  late bool _restTimerEnabled;
  late int _defaultRestSeconds;
  late bool _watchWorkoutEnabled;

  // Whether a paired + installed watch app was detected — the toggle row
  // only shows once this resolves true (docs/40-watch-app-plan.md §6.4).
  // Null while the check is still in flight.
  bool? _watchAvailable;

  @override
  void initState() {
    super.initState();
    unawaited(_checkWatchAvailability());
  }

  Future<void> _checkWatchAvailability() async {
    final available = await ref.read(watchWorkoutServiceProvider).isWatchAppAvailable();
    if (mounted) setState(() => _watchAvailable = available);
  }

  void _initFromSettings(UserSettings s) {
    _unitSystem = s.unitSystem;
    _theme = s.theme;
    _language = s.language;
    _calorieGoal = s.dailyCalorieGoal;
    _proteinGoal = s.dailyProteinGoal;
    _carbsGoal = s.dailyCarbsGoal;
    _fatGoal = s.dailyFatGoal;
    _waterGoal = s.dailyWaterGoalLiters;
    _stepGoal = s.dailyStepGoal;
    _workoutReminderEnabled = s.workoutReminderEnabled;
    _trainerCommentPushEnabled = s.trainerCommentPushEnabled;
    _trainerGoalsPushEnabled = s.trainerGoalsPushEnabled;
    _programAssignedPushEnabled = s.programAssignedPushEnabled;
    _chatPushEnabled = s.chatPushEnabled;
    _restTimerEnabled = s.restTimerEnabled;
    _defaultRestSeconds = s.defaultRestSeconds;
    _watchWorkoutEnabled = s.watchWorkoutEnabled;
    _initialized = true;
  }

  void _autoSave() {
    ref
        .read(settingsControllerProvider.notifier)
        .save(
          UserSettings(
            unitSystem: _unitSystem,
            theme: _theme,
            language: _language,
            dailyCalorieGoal: _calorieGoal,
            dailyProteinGoal: _proteinGoal,
            dailyCarbsGoal: _carbsGoal,
            dailyFatGoal: _fatGoal,
            dailyWaterGoalLiters: _waterGoal,
            dailyStepGoal: _stepGoal,
            workoutReminderEnabled: _workoutReminderEnabled,
            trainerCommentPushEnabled: _trainerCommentPushEnabled,
            trainerGoalsPushEnabled: _trainerGoalsPushEnabled,
            programAssignedPushEnabled: _programAssignedPushEnabled,
            chatPushEnabled: _chatPushEnabled,
            restTimerEnabled: _restTimerEnabled,
            defaultRestSeconds: _defaultRestSeconds,
            watchWorkoutEnabled: _watchWorkoutEnabled,
          ),
        )
        .catchError((e) {
          if (mounted) {
            AppSnackbar.showError(context, title: friendlyError(e));
          }
        });
  }

  static const List<int> _restDurationPresets = [30, 45, 60, 90, 120, 150, 180, 240, 300];

  static String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // Opens a sheet picker for the default rest duration. Scrollable, since the 9
  // presets don't fit a fixed-height sheet on shorter screens.
  void _pickRestDuration(AppLocalizations l10n) {
    showLifeySheet<void>(
      context: context,
      title: l10n.restTimerDurationSheetTitle,
      builder: (sheetCtx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final seconds in _restDurationPresets)
            _ChoiceTile(
              label: _formatDuration(seconds),
              selected: _defaultRestSeconds == seconds,
              onTap: () {
                setState(() => _defaultRestSeconds = seconds);
                _autoSave();
                Navigator.of(sheetCtx).pop();
              },
            ),
        ],
      ),
    );
  }

  // Opens a sheet picker for Language.
  void _pickLanguage(AppLocalizations l10n) {
    showLifeySheet<void>(
      context: context,
      title: l10n.languageLabel,
      builder: (sheetCtx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final opt in LanguagePreference.values)
            _ChoiceTile(
              label: _languageName(opt, l10n),
              selected: _language == opt,
              onTap: () {
                setState(() => _language = opt);
                _autoSave();
                Navigator.of(sheetCtx).pop();
              },
            ),
        ],
      ),
    );
  }

  // Opens the editor of one numeric goal; [onSave] stores the text, the
  // autosave persists it.
  void _openGoalSheet({
    required String label,
    required String suffix,
    required String initialText,
    required bool decimal,
    required void Function(String text) onSave,
  }) {
    showGoalEditSheet(
      context,
      label: label,
      suffix: suffix,
      initialText: initialText,
      decimal: decimal,
      onSave: (text) {
        onSave(text);
        _autoSave();
      },
    );
  }

  // The take-photo / gallery / remove actions.
  void _openAvatarSheet(AppLocalizations l10n, {required bool hasAvatar}) {
    showLifeySheet<void>(
      context: context,
      title: l10n.changePhotoLabel,
      builder: (sheetCtx) {
        final scheme = Theme.of(sheetCtx).colorScheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera_outlined, color: scheme.primary),
              title: Text(l10n.takePhotoAction),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _pickAndUploadAvatar(ImageSource.camera, l10n);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: scheme.primary),
              title: Text(l10n.chooseFromGalleryAction),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _pickAndUploadAvatar(ImageSource.gallery, l10n);
              },
            ),
            if (hasAvatar)
              ListTile(
                leading: Icon(Icons.delete_outline, color: sheetCtx.metricColors.heart),
                title: Text(l10n.removePhotoAction, style: TextStyle(color: sheetCtx.metricColors.heart)),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _removeAvatar(l10n);
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _pickAndUploadAvatar(ImageSource source, AppLocalizations l10n) async {
    if (_avatarBusy) return;
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: source, maxWidth: 1024, imageQuality: 85);
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, title: friendlyError(e));
      return;
    }
    if (picked == null) return;

    setState(() => _avatarBusy = true);
    try {
      await ref.read(avatarControllerProvider.notifier).upload(File(picked.path));
      if (mounted) AppSnackbar.showSuccess(context, title: l10n.avatarUpdatedMessage);
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, title: friendlyError(e));
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Future<void> _removeAvatar(AppLocalizations l10n) async {
    if (_avatarBusy) return;
    setState(() => _avatarBusy = true);
    try {
      await ref.read(avatarControllerProvider.notifier).remove();
      if (mounted) AppSnackbar.showSuccess(context, title: l10n.avatarRemovedMessage);
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, title: friendlyError(e));
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    // Initialize form state once on first successful load.
    if (!_initialized) {
      state.whenData(_initFromSettings);
    }

    return Scaffold(
      body: ScrollCollapseListener(
        child: state.when(
          data: (_) => _initialized
              ? _buildContent(context, l10n)
              : CustomScrollView(slivers: [
                  LifeyHeader(title: l10n.settingsTitle, onBack: () => Navigator.of(context).maybePop()),
                  const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
                ]),
          loading: () => CustomScrollView(slivers: [
            LifeyHeader(title: l10n.settingsTitle, onBack: () => Navigator.of(context).maybePop()),
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
          ]),
          error: (error, _) => CustomScrollView(slivers: [
            LifeyHeader(title: l10n.settingsTitle, onBack: () => Navigator.of(context).maybePop()),
            SliverFillRemaining(
              child: ErrorView(error: error, onRetry: () => ref.invalidate(settingsControllerProvider)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations l10n) {
    final mc = context.metricColors;
    final authUser = ref.watch(authControllerProvider).value;
    final email = authUser?.email;
    final fullName = [authUser?.firstName, authUser?.lastName]
        .where((part) => part != null && part.isNotEmpty)
        .join(' ');
    final avatarBytes = ref.watch(avatarControllerProvider).value;
    final entitlement = ref.watch(entitlementProvider).value;
    final isPro = entitlement != null && entitlement.resolved && entitlement.tier == EntitlementTier.pro;
    final bottomPad = MediaQuery.paddingOf(context).bottom + AppSpacing.s32;

    void editInt(GoalKind kind, String label, String suffix, int? current, void Function(int?) set) => _openGoalSheet(
          label: label,
          suffix: suffix,
          initialText: current?.toString() ?? '',
          decimal: false,
          onSave: (text) => setState(() => set(text.trim().isEmpty ? null : int.parse(text.trim()))),
        );

    void editGoal(GoalKind kind) => switch (kind) {
          GoalKind.calories => editInt(kind, l10n.caloriesLabel, 'kcal', _calorieGoal, (v) => _calorieGoal = v),
          GoalKind.protein => editInt(kind, l10n.proteinLabel, 'g', _proteinGoal, (v) => _proteinGoal = v),
          GoalKind.carbs => editInt(kind, l10n.carbsLabel, 'g', _carbsGoal, (v) => _carbsGoal = v),
          GoalKind.fat => editInt(kind, l10n.fatLabel, 'g', _fatGoal, (v) => _fatGoal = v),
          GoalKind.steps => _openGoalSheet(
              label: l10n.stepsLabel,
              suffix: l10n.statUnitSteps,
              initialText: (_stepGoal ?? UserSettings.defaultDailyStepGoal).toString(),
              decimal: false,
              onSave: (text) => setState(() => _stepGoal = text.trim().isEmpty ? null : int.parse(text.trim())),
            ),
          GoalKind.water => _openGoalSheet(
              label: l10n.waterLabel,
              suffix: 'L',
              initialText: _waterGoal?.toString() ?? '',
              decimal: true,
              onSave: (text) => setState(
                () => _waterGoal = text.trim().isEmpty ? null : double.parse(text.replaceAll(',', '.').trim()),
              ),
            ),
        };

    const gutter = EdgeInsets.symmetric(horizontal: AppSpacing.screen);
    Widget group(String label, List<Widget> rows) => Padding(
          padding: gutter.copyWith(top: AppSpacing.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionLabel(label),
              const SizedBox(height: AppSpacing.s8),
              ListGroup(children: rows),
            ],
          ),
        );

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        LifeyHeader(title: l10n.settingsTitle, onBack: () => Navigator.of(context).maybePop()),
        SliverToBoxAdapter(
          child: Padding(
            padding: gutter.copyWith(top: AppSpacing.s16),
            child: SettingsProfileCard(
              name: fullName,
              email: email,
              avatarBytes: avatarBytes,
              busy: _avatarBusy,
              isPro: isPro,
              onTap: () => _openAvatarSheet(l10n, hasAvatar: avatarBytes != null),
            ),
          ),
        ),

        // ── Preferences ────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: group(l10n.preferencesLabel, [
            SettingsChoiceRow(
              icon: Icons.straighten_rounded,
              title: l10n.unitsLabel,
              control: InlinePillSegment<UnitSystem>(
                options: [
                  (UnitSystem.metric, l10n.unitsMetricShort),
                  (UnitSystem.imperial, l10n.unitsImperialShort),
                ],
                selected: _unitSystem,
                onChanged: (v) {
                  setState(() => _unitSystem = v);
                  _autoSave();
                },
              ),
            ),
            SettingsChoiceRow(
              icon: Icons.dark_mode_outlined,
              title: l10n.themeLabel,
              control: InlinePillSegment<ThemePreference>(
                options: [
                  (ThemePreference.light, l10n.themeLight),
                  (ThemePreference.dark, l10n.themeDark),
                  (ThemePreference.system, l10n.optionSystem),
                ],
                selected: _theme,
                onChanged: (v) {
                  setState(() => _theme = v);
                  _autoSave();
                },
              ),
            ),
            SettingsRow(
              icon: Icons.translate_rounded,
              title: l10n.languageLabel,
              onTap: () => _pickLanguage(l10n),
              trailing: SettingsValue(_languageName(_language, l10n)),
            ),
          ]),
        ),

        // ── Daily goals ────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: gutter.copyWith(top: AppSpacing.s24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // "Edit" opens Body & goals, which recalculates the goals from
                // the body details; the tiles below edit one number each.
                SectionLabel(
                  l10n.dailyGoalsLabel,
                  actionLabel: l10n.settingsGoalsEditAction,
                  onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnboardingEditScreen())),
                ),
                const SizedBox(height: AppSpacing.s8),
                DailyGoalTiles(
                  calories: _calorieGoal,
                  protein: _proteinGoal,
                  carbs: _carbsGoal,
                  fat: _fatGoal,
                  waterLiters: _waterGoal,
                  steps: _stepGoal,
                  onEdit: editGoal,
                ),
              ],
            ),
          ),
        ),

        // ── Workout (docs/39-rest-timer-plan.md §3.2) ─────────────────────
        SliverToBoxAdapter(
          child: group(l10n.workoutSectionLabel, [
            SettingsRow(
              icon: Icons.timer_outlined,
              title: l10n.restTimerToggleLabel,
              trailing: SettingsSwitch(
                value: _restTimerEnabled,
                onChanged: (v) {
                  setState(() => _restTimerEnabled = v);
                  _autoSave();
                  if (v) {
                    // Exact-alarm permission is requested here (an explicit
                    // user action) rather than mid-workout — see
                    // docs/39-rest-timer-plan.md §2.3.
                    unawaited(NotificationService.requestRestTimerExactAlarmPermission());
                  } else {
                    unawaited(NotificationService.cancelRestEnd());
                  }
                },
              ),
            ),
            SettingsRow(
              icon: Icons.hourglass_bottom_rounded,
              title: l10n.restTimerDurationLabel,
              onTap: () => _pickRestDuration(l10n),
              trailing: SettingsValue(_formatDuration(_defaultRestSeconds)),
            ),
            // Only shown once a paired + installed watch app was detected
            // (docs/40-watch-app-plan.md §6.4) — a live check, not persisted,
            // so it can also disappear again if the watch is later unpaired.
            if (_watchAvailable == true)
              SettingsRow(
                icon: Icons.watch_outlined,
                title: l10n.watchWorkoutToggleLabel,
                trailing: SettingsSwitch(
                  value: _watchWorkoutEnabled,
                  onChanged: (v) {
                    setState(() => _watchWorkoutEnabled = v);
                    _autoSave();
                  },
                ),
              ),
          ]),
        ),

        // ── Integrations ───────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: group(l10n.integrationsLabel, [
            SettingsRow(
              icon: Icons.water_drop_outlined,
              title: l10n.manageWaterSourcesButton,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WaterSourcesScreen())),
              trailing: const SettingsValue(''),
            ),
            // Health (Apple Health on iOS, Health Connect on Android)
            if (Platform.isIOS || Platform.isAndroid) const HealthIntegrationRow(),
            // Notifications (docs/30-push-notifications-plan.md, M5)
            NotificationsRow(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())),
            ),
          ]),
        ),

        // ── My trainers (hidden entirely when there are none) ─────────────
        const SliverToBoxAdapter(child: Padding(padding: gutter, child: MyTrainersSection())),

        // ── Subscription (docs/landing_page/67-mobile-free-pro-plan.md §4.4,
        // frame P14) ─────────────────────────────────────────────────────────
        const SliverToBoxAdapter(child: Padding(padding: gutter, child: SubscriptionSection())),

        // ── Account ────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: group(l10n.accountLabel, [
            if (email != null)
              // The address is the row's subline, so it is always shown in full
              // (a trailing value would be cut to "anna.r5@life…" at 130 %).
              SettingsRow(icon: Icons.mail_outline_rounded, title: l10n.emailLabel, subtitle: email),
            SettingsRow(
              icon: Icons.lock_outline_rounded,
              title: l10n.changePasswordButton,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
              trailing: const SettingsValue(''),
            ),
            SettingsRow(
              icon: Icons.accessibility_new_rounded,
              title: l10n.onboardingProfileTileLabel,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnboardingEditScreen())),
              trailing: const SettingsValue(''),
            ),
            // Bottom of the screen on purpose: moved here from the dashboard
            // header, where one tap wiped the local data
            // (docs/redesign/77-mobile-redesign-plan.md R1.1).
            SettingsRow(
              icon: Icons.logout_rounded,
              title: l10n.logOutLabel,
              color: mc.heart,
              onTap: _confirmLogout,
            ),
          ]),
        ),

        // ── Debug (debug builds only) ──────────────────────────────────────
        // The design gallery for the redesign reviews
        // (docs/redesign/77-mobile-redesign-plan.md R0.6). Never in a release
        // build, so its labels are deliberately not in the ARB.
        if (kDebugMode)
          SliverToBoxAdapter(
            child: group('Debug', [
              SettingsRow(
                icon: Icons.palette_outlined,
                title: 'Design gallery',
                onTap: () => context.push(DesignGalleryScreen.routePath),
                trailing: const SettingsValue(''),
              ),
            ]),
          ),
        SliverToBoxAdapter(child: SizedBox(height: bottomPad)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _confirmLogout() async {
    final preflight = ref.read(logoutPreflightProvider);
    final plan = await preflight.plan();
    if (!mounted) return;
    final confirmed = await showLogoutDialog(context, plan: plan);
    if (!confirmed || !mounted) return;
    // Queued changes go up before anything is wiped; a small progress dialog
    // says so while they do (bounded — a bad connection cannot hold it).
    if (plan.willUpload) await _uploadBeforeLogout(preflight);
    if (!mounted) return;
    // The router redirects to the login screen once auth state clears.
    await ref.read(authControllerProvider.notifier).logout(flush: false);
  }

  Future<void> _uploadBeforeLogout(LogoutPreflight preflight) async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context, rootNavigator: true);
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
              const SizedBox(width: AppSpacing.s16),
              Expanded(child: Text(l10n.logOutUploadingMessage)),
            ],
          ),
        ),
      ),
    ));
    try {
      await preflight.flush();
    } finally {
      if (navigator.canPop()) navigator.pop();
    }
  }

  String _languageName(LanguagePreference pref, AppLocalizations l10n) {
    return switch (pref) {
      LanguagePreference.system => l10n.optionSystem,
      LanguagePreference.english => l10n.languageEnglish,
      LanguagePreference.hungarian => l10n.languageHungarian,
    };
  }

}

/// One option of a picker sheet: the label and, when chosen, a check.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListTile(
      title: Text(label, style: Theme.of(context).textTheme.titleMedium!.copyWith(color: p.text)),
      trailing: selected ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary) : null,
      onTap: onTap,
    );
  }
}
