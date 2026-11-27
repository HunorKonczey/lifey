import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/health/cardio_import_controller.dart';
import '../../../../core/health/health_connect_route_access.dart';
import '../../../../core/health/health_controller.dart';
import '../../../../core/health/sleep_import_controller.dart';
import '../../../../core/health/vitals_import_controller.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/notification_settings_controller.dart';
import 'settings_kit.dart';

/// The Health row (Apple Health on iOS, Health Connect on Android): a switch,
/// and under the title what the current state means — "Off · weight and steps
/// are logged by hand" — read from the real connection, so the line can never
/// disagree with the switch (canvas: "Őszinte kapcsolók").
class HealthIntegrationRow extends ConsumerWidget {
  const HealthIntegrationRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(healthControllerProvider);
    final enabled = state.value ?? false;

    return SettingsRow(
      icon: Icons.favorite_rounded,
      title: l10n.healthIntegrationLabel,
      subtitle: enabled ? l10n.settingsHealthOnSubtitle : l10n.settingsHealthOffSubtitle,
      trailing: SettingsSwitch(
        value: enabled,
        onChanged: state.isLoading ? null : (v) => ref.read(healthControllerProvider.notifier).setEnabled(v),
      ),
    );
  }
}

/// "Cardio from other apps": the opt-in that imports finished runs and rides
/// that other apps (Garmin Connect and the like) wrote to the health store
/// (docs/integrations/89 G1.6, D-G5).
///
/// Sits under the Health row and depends on it. While Health is off the
/// switch is disabled and the line says so; no state can claim an import
/// that won't happen. On Android, a revoked Health Connect permission shows
/// as "Permission needed", and tapping the row asks again.
class CardioImportRow extends ConsumerWidget {
  const CardioImportRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final healthOn = ref.watch(healthControllerProvider).value ?? false;
    final state = ref.watch(cardioImportControllerProvider);
    final status = state.value;
    final enabled = status?.enabled ?? false;
    final permissionMissing = healthOn && enabled && (status?.permissionMissing ?? false);
    final controller = ref.read(cardioImportControllerProvider.notifier);

    final String subtitle;
    if (!healthOn) {
      subtitle = l10n.settingsCardioImportNeedsHealthSubtitle;
    } else if (permissionMissing) {
      subtitle = l10n.settingsCardioImportPermissionSubtitle;
    } else {
      subtitle = enabled ? l10n.settingsCardioImportOnSubtitle : l10n.settingsCardioImportOffSubtitle;
    }

    return SettingsRow(
      icon: Icons.directions_run_rounded,
      title: l10n.settingsCardioImportLabel,
      subtitle: subtitle,
      onTap: permissionMissing ? controller.requestPermissionAgain : null,
      trailing: SettingsSwitch(
        // Shown as off while Health is off: the import can't run then, whatever the stored opt-in says.
        value: healthOn && enabled,
        onChanged: !healthOn || state.isLoading ? null : controller.setEnabled,
      ),
    );
  }
}

/// "Sleep from other apps": the opt-in that imports sleep sessions other
/// apps (Garmin Connect, an Apple Watch and the like) wrote to the health
/// store (docs/integrations/89 G2.4, D-G5). The same rules as
/// [CardioImportRow]: it depends on the Health row, the line under the title
/// never claims an import that won't happen, and a revoked Health Connect
/// permission shows as "Permission needed", with a tap asking again.
class SleepImportRow extends ConsumerWidget {
  const SleepImportRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final healthOn = ref.watch(healthControllerProvider).value ?? false;
    final state = ref.watch(sleepImportControllerProvider);
    final status = state.value;
    final enabled = status?.enabled ?? false;
    final permissionMissing = healthOn && enabled && (status?.permissionMissing ?? false);
    final controller = ref.read(sleepImportControllerProvider.notifier);

    final String subtitle;
    if (!healthOn) {
      subtitle = l10n.settingsSleepImportNeedsHealthSubtitle;
    } else if (permissionMissing) {
      subtitle = l10n.settingsSleepImportPermissionSubtitle;
    } else {
      subtitle = enabled ? l10n.settingsSleepImportOnSubtitle : l10n.settingsSleepImportOffSubtitle;
    }

    return SettingsRow(
      icon: Icons.bedtime_rounded,
      title: l10n.settingsSleepImportLabel,
      subtitle: subtitle,
      onTap: permissionMissing ? controller.requestPermissionAgain : null,
      trailing: SettingsSwitch(
        // Shown as off while Health is off: the import can't run then, whatever the stored opt-in says.
        value: healthOn && enabled,
        onChanged: !healthOn || state.isLoading ? null : controller.setEnabled,
      ),
    );
  }
}

/// "Resting heart rate & HRV" — the vitals import opt-in under Health
/// (docs/integrations/89 G3.3, D-G5), the same shape as [SleepImportRow].
class VitalsImportRow extends ConsumerWidget {
  const VitalsImportRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final healthOn = ref.watch(healthControllerProvider).value ?? false;
    final state = ref.watch(vitalsImportControllerProvider);
    final status = state.value;
    final enabled = status?.enabled ?? false;
    final permissionMissing = healthOn && enabled && (status?.permissionMissing ?? false);
    final controller = ref.read(vitalsImportControllerProvider.notifier);

    final String subtitle;
    if (!healthOn) {
      subtitle = l10n.settingsVitalsImportNeedsHealthSubtitle;
    } else if (permissionMissing) {
      subtitle = l10n.settingsVitalsImportPermissionSubtitle;
    } else {
      subtitle = enabled ? l10n.settingsVitalsImportOnSubtitle : l10n.settingsVitalsImportOffSubtitle;
    }

    return SettingsRow(
      icon: Icons.monitor_heart_rounded,
      title: l10n.settingsVitalsImportLabel,
      subtitle: subtitle,
      onTap: permissionMissing ? controller.requestPermissionAgain : null,
      trailing: SettingsSwitch(
        // Shown as off while Health is off: the import can't run then, whatever the stored opt-in says.
        value: healthOn && enabled,
        onChanged: !healthOn || state.isLoading ? null : controller.setEnabled,
      ),
    );
  }
}

/// "Route maps from other apps ›" — under the cardio-import row on Android,
/// while the import runs but Health Connect withholds other apps' routes
/// (docs/integrations/89 G1.8, LIF-223). That permission, *Exercise routes*,
/// can only be granted in Health Connect, so without this row an imported
/// Garmin run simply has no map and the user never learns why. Tapping opens
/// Health Connect; the subline names the path from there.
///
/// It leaves once the permission is granted. That is known from Android 14;
/// below, Health Connect can't tell, so the row stays while the import is on.
/// The check reruns on every app resume, since the grant happens in another
/// app.
class ExerciseRoutesHintRow extends ConsumerStatefulWidget {
  const ExerciseRoutesHintRow({super.key});

  @override
  ConsumerState<ExerciseRoutesHintRow> createState() => _ExerciseRoutesHintRowState();
}

class _ExerciseRoutesHintRowState extends ConsumerState<ExerciseRoutesHintRow> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => ref.invalidate(exerciseRoutesGrantedProvider));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final opened = await ref.read(healthConnectRouteAccessProvider).openHealthConnect();
    if (opened || !mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settingsExerciseRoutesOpenFailedMessage)));
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(healthConnectRouteAccessProvider);
    final healthOn = ref.watch(healthControllerProvider).value ?? false;
    final status = ref.watch(cardioImportControllerProvider).value;
    // Only while the import itself works: off, Health off, or the workout permission gone each has its own line on
    // the row above, and a route hint on top would only add noise.
    final importRunning = healthOn && (status?.enabled ?? false) && !(status?.permissionMissing ?? false);
    if (!access.isAvailable || !importRunning) return const SizedBox.shrink();

    final granted = ref.watch(exerciseRoutesGrantedProvider);
    // Hidden until the first answer, so a granted permission never flashes the row; a resume re-check keeps the
    // previous answer on screen meanwhile.
    if (!granted.hasValue || granted.value == true) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    return SettingsRow(
      icon: Icons.route_rounded,
      title: l10n.settingsExerciseRoutesLabel,
      subtitle: l10n.settingsExerciseRoutesSubtitle,
      onTap: _open,
      trailing: const SettingsValue(''),
    );
  }
}

/// "Notifications · 3 on ›" — how many notification types are switched on,
/// counted from the same state the notification screen edits.
class NotificationsRow extends ConsumerWidget {
  const NotificationsRow({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final count = ref.watch(notificationSettingsControllerProvider).value?.enabledCount;
    return SettingsRow(
      icon: Icons.notifications_none_rounded,
      title: l10n.notificationsSettingsTileLabel,
      onTap: onTap,
      trailing: SettingsValue(
        count == null ? '' : (count == 0 ? l10n.settingsNotificationsAllOff : l10n.settingsNotificationsOnCount(count)),
      ),
    );
  }
}
