import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/health/cardio_import_controller.dart';
import '../../../../core/health/health_controller.dart';
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
