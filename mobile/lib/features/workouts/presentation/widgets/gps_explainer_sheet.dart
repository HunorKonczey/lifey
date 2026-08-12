import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';

/// What the user chose on [GpsExplainerSheet] — both branches proceed to
/// start the session (docs/cardio/51 D-C.5: GPS never blocks starting), only
/// [requestPermission] additionally shows the system permission dialog
/// first. A `null` result (swiped away / tapped outside) is treated the same
/// as [skipGps] by the caller — see `showGpsExplainerSheet`'s doc.
enum GpsExplainerChoice { requestPermission, skipGps }

/// One-time explainer shown before the system location-permission dialog,
/// the first time ever a DISTANCE-family session is started
/// (docs/cardio/54-cardio-gps-route-plan.md §3.1, M26). Never shown again
/// after this — see `LocationPermissionPreferences`.
class GpsExplainerSheet extends StatelessWidget {
  const GpsExplainerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.near_me_rounded, color: scheme.primary, size: 32),
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(
            l10n.gpsExplainerTitle,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            l10n.gpsExplainerBody,
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.s16),
          _Bullet(icon: Icons.route, label: l10n.gpsExplainerBulletRoute),
          const SizedBox(height: 10),
          _Bullet(icon: Icons.speed, label: l10n.gpsExplainerBulletPace),
          const SizedBox(height: 10),
          _Bullet(icon: Icons.cloud_off, label: l10n.gpsExplainerBulletPrivacy),
          const SizedBox(height: AppSpacing.s24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(GpsExplainerChoice.requestPermission),
              child: Text(l10n.gpsExplainerGrantButton),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          // A real button, not a text link — "Indítás GPS nélkül" needs the
          // same touch target as the primary action (M26's own design note).
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(GpsExplainerChoice.skipGps),
              child: Text(l10n.gpsExplainerSkipButton),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Center(
            child: Text(
              l10n.gpsExplainerFootnote,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.sm + 4),
          ),
          child: Icon(icon, size: 19, color: scheme.primary),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Shows [GpsExplainerSheet] and returns the user's choice. A `null` result
/// (dismissed without tapping either button) is the caller's responsibility
/// to treat as [GpsExplainerChoice.skipGps] — the sheet is only ever shown
/// once regardless of how it closes, so an ignored sheet must still count as
/// "seen" (see `LocationPermissionPreferences`), just without requesting.
Future<GpsExplainerChoice?> showGpsExplainerSheet(BuildContext context) {
  return showModalBottomSheet<GpsExplainerChoice>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const GpsExplainerSheet(),
  );
}
