import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
